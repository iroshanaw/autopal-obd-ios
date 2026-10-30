import Foundation
import AutopalCore

/// Manages active connection lifecycle and bridges `ObdClient` to the app.
/// Actor isolated per ARCHITECTURE §6.1.
public actor ConnectionManager {
    public enum Mode: Sendable, Equatable {
        case disconnected
        case demo(scenario: SimulatedElm327Transport.Scenario)
        case ble(peripheralName: String)
        case wifi(host: String, port: Int)
    }
    
    private var activeMode: Mode = .disconnected
    private var client: ObdClient?
    private var simulatedTransport: SimulatedElm327Transport?
    private var bleTransport: BleTransport?
    private var pollTask: Task<Void, Never>?
    
    // Snapshot stream for UI observation
    private var snapshotContinuation: AsyncStream<VehicleSnapshot>.Continuation?
    public let snapshots: AsyncStream<VehicleSnapshot>
    
    public init() {
        var continuation: AsyncStream<VehicleSnapshot>.Continuation?
        self.snapshots = AsyncStream { cont in
            continuation = cont
        }
        self.snapshotContinuation = continuation
    }
    
    public var mode: Mode {
        activeMode
    }
    
    /// Connects in Demo mode with the specified simulated vehicle scenario.
    public func connectDemo(scenario: SimulatedElm327Transport.Scenario = .normal) {
        disconnect()
        
        activeMode = .demo(scenario: scenario)
        let clock = ContinuousClock()
        let transport = SimulatedElm327Transport(scenario: scenario, clock: clock)
        self.simulatedTransport = transport
        
        let client = ObdClient(transport: transport, clock: clock)
        self.client = client
        
        startForwarding(from: client, transport: transport)
    }
    
    /// Dynamically switches scenario while staying in Demo mode.
    public func setDemoScenario(_ scenario: SimulatedElm327Transport.Scenario) {
        guard case .demo = activeMode, let transport = simulatedTransport else {
            connectDemo(scenario: scenario)
            return
        }
        activeMode = .demo(scenario: scenario)
        Task {
            await transport.setScenario(scenario)
        }
    }
    
    /// Connects to a physical BLE OBD-II adapter (e.g. IOS-VLINK).
    public func connectBle(peripheralName: String? = "IOS-VLINK", peripheralId: UUID? = nil) {
        disconnect()
        
        activeMode = .ble(peripheralName: peripheralName ?? "OBD Adapter")
        let transport = BleTransport(targetName: peripheralName, targetId: peripheralId)
        self.bleTransport = transport
        
        let clock = ContinuousClock()
        let client = ObdClient(
            transport: transport,
            clock: clock,
            adapter: "ELM327",
            transportType: "BLE",
            device: peripheralName ?? "IOS-VLINK"
        )
        self.client = client
        
        startForwarding(from: client, transport: transport)
    }
    
    /// Disconnects the current session and stops all polling.
    public func disconnect() {
        pollTask?.cancel()
        pollTask = nil
        client = nil
        simulatedTransport = nil
        
        if let ble = bleTransport {
            Task { await ble.close() }
            bleTransport = nil
        }
        activeMode = .disconnected
        
        // Emit disconnected snapshot
        snapshotContinuation?.yield(
            VehicleSnapshot(
                phase: .disconnected,
                adapterVersion: nil,
                protocolId: nil,
                isCan: false,
                hintEnabled: false,
                vin: nil,
                supportedPids: [],
                readings: [:],
                readiness: nil,
                storedDtcs: [],
                pendingDtcs: [],
                activeAlerts: [],
                timestampMs: 0
            )
        )
    }
    
    /// Returns the exported traffic log of the current/last session.
    public func exportTrafficLog() async -> String? {
        await client?.trafficLogExport()
    }
    
    private func startForwarding(from client: ObdClient, transport: any ObdTransport) {
        pollTask = Task { [weak self, client] in
            // Emit connecting state
            await self?.yieldSnapshot(VehicleSnapshot(phase: .connecting))
            
            do {
                try await transport.connect()
            } catch {
                await self?.yieldSnapshot(VehicleSnapshot(phase: .disconnected))
                return
            }
            
            await client.start()
            var snap = await client.currentSnapshot
            await self?.yieldSnapshot(snap)
            
            if snap.phase == .live {
                (transport as? BleTransport)?.confirmPipeVerified()
            }
            
            while !Task.isCancelled {
                await client.stepPollCycle()
                snap = await client.currentSnapshot
                await self?.yieldSnapshot(snap)
                
                if snap.phase == .live {
                    (transport as? BleTransport)?.confirmPipeVerified()
                }
                
                if snap.phase == .disconnected || snap.phase == .noEcu {
                    break
                }
                
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
    
    private func yieldSnapshot(_ snapshot: VehicleSnapshot) {
        snapshotContinuation?.yield(snapshot)
    }
}
