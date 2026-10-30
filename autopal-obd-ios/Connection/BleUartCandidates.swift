import Foundation
import CoreBluetooth

/// Represents a candidate BLE UART pipe consisting of a service, notify, and write characteristic.
nonisolated public struct BleUartPipe: Sendable, Equatable, Hashable, Codable {
    public let serviceUUID: String
    public let notifyUUID: String
    public let writeUUID: String
    public let name: String
    
    public init(serviceUUID: String, notifyUUID: String, writeUUID: String, name: String) {
        self.serviceUUID = serviceUUID
        self.notifyUUID = notifyUUID
        self.writeUUID = writeUUID
        self.name = name
    }
    
    public var serviceCBUUID: CBUUID { CBUUID(string: serviceUUID) }
    public var notifyCBUUID: CBUUID { CBUUID(string: notifyUUID) }
    public var writeCBUUID: CBUUID { CBUUID(string: writeUUID) }
}

/// Resolved pair of CoreBluetooth characteristics for OBD communication.
nonisolated public struct ResolvedBlePipe: @unchecked Sendable {
    public let pipe: BleUartPipe
    public let notifyCharacteristic: CBCharacteristic
    public let writeCharacteristic: CBCharacteristic
    
    public init(pipe: BleUartPipe, notifyCharacteristic: CBCharacteristic, writeCharacteristic: CBCharacteristic) {
        self.pipe = pipe
        self.notifyCharacteristic = notifyCharacteristic
        self.writeCharacteristic = writeCharacteristic
    }
}

/// The ONLY file in the project where BLE UUIDs are declared (ARCHITECTURE §4.3).
/// A pipe is accepted only when ATZ returns text containing ELM327.
nonisolated public enum BleUartCandidates: Sendable {
    
    /// Pipe 2: Confirmed on IOS-VLINK (JINXUSOLU JXSL-MIC34LE clone) [Certain]
    public static let iosVlink = BleUartPipe(
        serviceUUID: "18F0",
        notifyUUID: "2AF0",
        writeUUID: "2AF1",
        name: "IOS-VLINK (18F0)"
    )
    
    /// Pipe 3: Common clones [Likely]
    public static let commonClone = BleUartPipe(
        serviceUUID: "FFF0",
        notifyUUID: "FFF1",
        writeUUID: "FFF2",
        name: "Common Clone (FFF0)"
    )
    
    /// Pipe 4: HM-10 style [Likely]
    public static let hm10 = BleUartPipe(
        serviceUUID: "FFE0",
        notifyUUID: "FFE1",
        writeUUID: "FFE1",
        name: "HM-10 (FFE0)"
    )
    
    /// Pipe 5: Genuine Vgate [Guessing]; ruled out on this clone's iOS persona
    public static let vgate = BleUartPipe(
        serviceUUID: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2",
        notifyUUID: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F",
        writeUUID: "BEF8D6C9-9C21-4C9E-B632-BD58C1009F9F",
        name: "Vgate (E781)"
    )
    
    /// Standard candidate list in priority order (§4.3)
    public static let standardCandidates: [BleUartPipe] = [
        iosVlink,
        commonClone,
        hm10,
        vgate
    ]
    
    // MARK: - Pipe Persistence
    
    private static let defaultsKeyPrefix = "autopal_ble_verified_pipe_"
    
    /// Returns the verified pipe saved for this peripheral identifier, if any.
    public static func savedPipe(for peripheralId: UUID, suiteName: String = "group.com.autopal.obd") -> BleUartPipe? {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let key = defaultsKeyPrefix + peripheralId.uuidString
        guard let data = defaults.data(forKey: key),
              let pipe = try? JSONDecoder().decode(BleUartPipe.self, from: data) else {
            return nil
        }
        return pipe
    }
    
    /// Saves a confirmed pipe after ATZ returns text containing ELM327.
    public static func saveVerifiedPipe(_ pipe: BleUartPipe, for peripheralId: UUID, suiteName: String = "group.com.autopal.obd") {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        let key = defaultsKeyPrefix + peripheralId.uuidString
        if let data = try? JSONEncoder().encode(pipe) {
            defaults.set(data, forKey: key)
        }
    }
    
    /// Resolves the candidate pipe and matching CBCharacteristics from discovered services.
    /// Priority order:
    /// 1. Saved pipe for this peripheral identifier
    /// 2. 18F0 / 2AF0 / 2AF1 (IOS-VLINK)
    /// 3. FFF0 / FFF1 / FFF2
    /// 4. FFE0 / FFE1 / FFE1
    /// 5. E781...
    /// 6. Heuristic: any non-standard service with notify + write
    public static func resolvePipe(
        in services: [CBService],
        for peripheralId: UUID,
        suiteName: String = "group.com.autopal.obd"
    ) -> ResolvedBlePipe? {
        // Build list of candidate pipes to test
        var candidates: [BleUartPipe] = []
        if let saved = savedPipe(for: peripheralId, suiteName: suiteName) {
            candidates.append(saved)
        }
        for standard in standardCandidates {
            if !candidates.contains(standard) {
                candidates.append(standard)
            }
        }
        
        // 1. Try defined candidates
        for candidate in candidates {
            if let service = services.first(where: { $0.uuid == candidate.serviceCBUUID }),
               let characteristics = service.characteristics {
                if let notifyChar = characteristics.first(where: { $0.uuid == candidate.notifyCBUUID }),
                   let writeChar = characteristics.first(where: { $0.uuid == candidate.writeCBUUID }) {
                    return ResolvedBlePipe(
                        pipe: candidate,
                        notifyCharacteristic: notifyChar,
                        writeCharacteristic: writeChar
                    )
                }
            }
        }
        
        // 2. Heuristic: any service offering both a notify characteristic and a write characteristic
        for service in services {
            // Ignore standard Apple/Bluetooth SIG utility services (e.g. Battery, Device Information)
            let sUUID = service.uuid.uuidString.uppercased()
            if sUUID == "180A" || sUUID == "180F" || sUUID == "1800" || sUUID == "1801" {
                continue
            }
            guard let characteristics = service.characteristics else { continue }
            
            let notifyChar = characteristics.first {
                $0.properties.contains(.notify) || $0.properties.contains(.indicate)
            }
            let writeChar = characteristics.first {
                $0.properties.contains(.writeWithoutResponse) || $0.properties.contains(.write)
            }
            
            if let notifyChar, let writeChar {
                let heuristicPipe = BleUartPipe(
                    serviceUUID: service.uuid.uuidString,
                    notifyUUID: notifyChar.uuid.uuidString,
                    writeUUID: writeChar.uuid.uuidString,
                    name: "Heuristic (\(service.uuid.uuidString))"
                )
                return ResolvedBlePipe(
                    pipe: heuristicPipe,
                    notifyCharacteristic: notifyChar,
                    writeCharacteristic: writeChar
                )
            }
        }
        
        return nil
    }
}
