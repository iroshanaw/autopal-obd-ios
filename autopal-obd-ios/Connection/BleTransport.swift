import Foundation
import CoreBluetooth
import AutopalCore

/// Represents a discovered BLE peripheral matching OBD-II candidate adapters.
nonisolated public struct DiscoveredBleAdapter: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let isPreferred: Bool
    
    public init(id: UUID, name: String, rssi: Int, isPreferred: Bool) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.isPreferred = isPreferred
    }
}

/// BLE OBD-II transport communicating over CoreBluetooth UART pipe (ARCHITECTURE §4.2).
/// Connects to ELM327 BLE adapters (e.g. IOS-VLINK / JXSL-MIC34LE), resolves UART characteristics,
/// enables notifications, and streams bytes to/from ElmSession.
nonisolated public final class BleTransport: NSObject, ObdTransport, @unchecked Sendable {
    public let label: String
    
    // ObdTransport streams
    public let linkState: AsyncStream<LinkState>
    public let incoming: AsyncStream<Data>
    
    // Discovered adapters stream for UI
    public let discoveredAdapters: AsyncStream<DiscoveredBleAdapter>
    
    // Continuations
    private var linkStateContinuation: AsyncStream<LinkState>.Continuation?
    private var incomingContinuation: AsyncStream<Data>.Continuation?
    private var discoveredContinuation: AsyncStream<DiscoveredBleAdapter>.Continuation?
    
    // Configuration
    private let targetName: String?
    private let targetId: UUID?
    private let bleQueue = DispatchQueue(label: "com.autopal.obd.ble", qos: .userInitiated)
    
    // CoreBluetooth State
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var resolvedPipe: ResolvedBlePipe?
    private var writeType: CBCharacteristicWriteType = .withoutResponse
    
    // Continuations for async operations
    private var connectContinuation: CheckedContinuation<Void, any Error>?
    private var writeContinuation: CheckedContinuation<Void, any Error>?
    private var isConnecting = false
    private var isClosed = false
    
    public init(targetName: String? = nil, targetId: UUID? = nil) {
        self.targetName = targetName
        self.targetId = targetId
        self.label = targetName.map { "BLE (\($0))" } ?? "BLE"
        
        var lsCont: AsyncStream<LinkState>.Continuation?
        self.linkState = AsyncStream { cont in lsCont = cont }
        self.linkStateContinuation = lsCont
        
        var inCont: AsyncStream<Data>.Continuation?
        self.incoming = AsyncStream { cont in inCont = cont }
        self.incomingContinuation = inCont
        
        var discCont: AsyncStream<DiscoveredBleAdapter>.Continuation?
        self.discoveredAdapters = AsyncStream { cont in discCont = cont }
        self.discoveredContinuation = discCont
        
        super.init()
    }
    
    deinit {
        linkStateContinuation?.finish()
        incomingContinuation?.finish()
        discoveredContinuation?.finish()
    }
    
    // MARK: - ObdTransport Implementation
    
    public func connect() async throws {
        isClosed = false
        linkStateContinuation?.yield(.connecting)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            bleQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: NSError(domain: "AutopalBLE", code: -1, userInfo: [NSLocalizedDescriptionKey: "Deallocated"]))
                    return
                }
                self.connectContinuation = continuation
                self.isConnecting = true
                
                if self.centralManager == nil {
                    self.centralManager = CBCentralManager(
                        delegate: self,
                        queue: self.bleQueue,
                        options: [
                            CBCentralManagerOptionRestoreIdentifierKey: "com.autopal.obd.central",
                            CBCentralManagerOptionShowPowerAlertKey: true
                        ]
                    )
                } else {
                    self.handleCentralState(self.centralManager!.state)
                }
            }
        }
    }
    
    public func write(_ bytes: Data) async throws {
        guard !isClosed, let peripheral, let resolvedPipe else {
            throw NSError(domain: "AutopalBLE", code: -2, userInfo: [NSLocalizedDescriptionKey: "Not connected"])
        }
        
        let writeChar = resolvedPipe.writeCharacteristic
        let maxChunkSize = peripheral.maximumWriteValueLength(for: writeType)
        
        if bytes.count <= maxChunkSize {
            try await writeChunk(bytes, to: writeChar, on: peripheral)
        } else {
            // Chunked write
            var offset = 0
            while offset < bytes.count {
                let chunkLength = min(maxChunkSize, bytes.count - offset)
                let chunk = bytes.subdata(in: offset..<(offset + chunkLength))
                try await writeChunk(chunk, to: writeChar, on: peripheral)
                offset += chunkLength
            }
        }
    }
    
    private func writeChunk(_ chunk: Data, to characteristic: CBCharacteristic, on peripheral: CBPeripheral) async throws {
        if writeType == .withoutResponse {
            peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
        } else {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                bleQueue.async { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: NSError(domain: "AutopalBLE", code: -1, userInfo: nil))
                        return
                    }
                    self.writeContinuation = continuation
                    peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
                }
            }
        }
    }
    
    public func close() async {
        isClosed = true
        bleQueue.async { [weak self] in
            guard let self else { return }
            if let central = self.centralManager, central.isScanning {
                central.stopScan()
            }
            if let peripheral = self.peripheral, let central = self.centralManager {
                central.cancelPeripheralConnection(peripheral)
            }
            self.peripheral = nil
            self.resolvedPipe = nil
            self.linkStateContinuation?.yield(.disconnected)
        }
    }
    
    /// Persists the active pipe as verified once ATZ returns an ELM327 response.
    public func confirmPipeVerified() {
        bleQueue.async { [weak self] in
            guard let self, let peripheral = self.peripheral, let resolved = self.resolvedPipe else { return }
            BleUartCandidates.saveVerifiedPipe(resolved.pipe, for: peripheral.identifier)
        }
    }
    
    // MARK: - Central State & Scanning
    
    private func handleCentralState(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            // Check if we can reconnect directly to known peripheral
            if let targetId {
                let peripherals = centralManager?.retrievePeripherals(withIdentifiers: [targetId]) ?? []
                if let matched = peripherals.first {
                    connectToPeripheral(matched)
                    return
                }
            }
            // Otherwise, scan without service filter (clones often don't advertise UART UUID)
            centralManager?.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            
            // Set 30-second timeout for discovery
            bleQueue.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                guard let self, self.isConnecting, self.peripheral == nil else { return }
                self.centralManager?.stopScan()
                self.failConnection(message: "No OBD adapter found within 30 seconds. Check power and replug if needed.")
            }
            
        case .poweredOff:
            failConnection(message: "Bluetooth is powered off. Please enable Bluetooth in Settings.")
        case .unauthorized:
            failConnection(message: "Bluetooth permission denied. Allow Bluetooth access in Settings.")
        case .unsupported:
            failConnection(message: "Bluetooth LE is not supported on this device.")
        default:
            break
        }
    }
    
    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        centralManager?.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }
    
    private func failConnection(message: String) {
        isConnecting = false
        linkStateContinuation?.yield(.failed(message))
        if let cont = connectContinuation {
            connectContinuation = nil
            cont.resume(throwing: NSError(domain: "AutopalBLE", code: -3, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
    
    private func isPreferredAdapterName(_ name: String) -> Bool {
        let upper = name.uppercased()
        return upper.contains("VLINK") ||
               upper.contains("OBD") ||
               upper.contains("ELM") ||
               upper.contains("VGATE")
    }
}

// MARK: - CBCentralManagerDelegate
extension BleTransport: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        handleCentralState(central.state)
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
           let restored = peripherals.first {
            connectToPeripheral(restored)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown"
        let isPreferred = isPreferredAdapterName(name)
        
        discoveredContinuation?.yield(
            DiscoveredBleAdapter(
                id: peripheral.identifier,
                name: name,
                rssi: RSSI.intValue,
                isPreferred: isPreferred
            )
        )
        
        // Auto-connect check
        guard isConnecting, self.peripheral == nil else { return }
        
        var matches = false
        if let targetId, peripheral.identifier == targetId {
            matches = true
        } else if let targetName, name.localizedCaseInsensitiveContains(targetName) {
            matches = true
        } else if targetName == nil && targetId == nil && isPreferred {
            matches = true
        }
        
        if matches {
            connectToPeripheral(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        failConnection(message: error?.localizedDescription ?? "Failed to connect to peripheral")
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        self.peripheral = nil
        self.resolvedPipe = nil
        linkStateContinuation?.yield(.disconnected)
    }
}

// MARK: - CBPeripheralDelegate
extension BleTransport: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        if let error {
            failConnection(message: "Service discovery error: \(error.localizedDescription)")
            return
        }
        guard let services = peripheral.services, !services.isEmpty else {
            failConnection(message: "No services found on peripheral")
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        if let error {
            failConnection(message: "Characteristic discovery error: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        // Check if all services have finished discovering characteristics
        let allDiscovered = services.allSatisfy { $0.characteristics != nil }
        guard allDiscovered else { return }
        
        // Resolve candidate pipe
        guard let resolved = BleUartCandidates.resolvePipe(in: services, for: peripheral.identifier) else {
            failConnection(message: "No compatible OBD UART service found. Replug adapter if used with Android.")
            return
        }
        
        self.resolvedPipe = resolved
        
        // Select write type: prefer .withoutResponse if supported per §4.2
        if resolved.writeCharacteristic.properties.contains(.writeWithoutResponse) {
            self.writeType = .withoutResponse
        } else {
            self.writeType = .withResponse
        }
        
        // Subscribe to notifications FIRST, and wait for didUpdateNotificationStateFor!
        peripheral.setNotifyValue(true, for: resolved.notifyCharacteristic)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let error {
            failConnection(message: "Failed to enable notifications: \(error.localizedDescription)")
            return
        }
        
        guard characteristic.isNotifying else {
            failConnection(message: "Notification state was not enabled on characteristic")
            return
        }
        
        // Notifications are active: transport is now fully connected and ready for I/O!
        isConnecting = false
        linkStateContinuation?.yield(.connected)
        if let cont = connectContinuation {
            connectContinuation = nil
            cont.resume()
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else { return }
        incomingContinuation?.yield(data)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        if let cont = writeContinuation {
            writeContinuation = nil
            if let error {
                cont.resume(throwing: error)
            } else {
                cont.resume()
            }
        }
    }
}
