import SwiftUI
import AutopalCore

/// Root application model created once in `MyApp` (ARCHITECTURE §6.1).
/// Coordinates `ConnectionManager`, `VehicleStore`, `SettingsStore`, `Entitlements`, `LiveActivityController`, and `CarPlaySceneDelegate`.
@Observable
@MainActor
public final class AppModel {
    public static private(set) var shared: AppModel?

    public let connectionManager: ConnectionManager
    public let vehicleStore: VehicleStore
    public let settingsStore: SettingsStore
    public let entitlements: any Entitlements
    
    private var previousPhase: ConnectionPhase = .disconnected
    private nonisolated(unsafe) var snapshotTask: Task<Void, Never>?
    
    public init(
        connectionManager: ConnectionManager = ConnectionManager(),
        vehicleStore: VehicleStore = VehicleStore(),
        settingsStore: SettingsStore = SettingsStore(),
        entitlements: any Entitlements = Stage1Entitlements()
    ) {
        self.connectionManager = connectionManager
        self.vehicleStore = vehicleStore
        self.settingsStore = settingsStore
        self.entitlements = entitlements
        
        AppModel.shared = self
        
        startObservingSnapshots()
        
        // Auto-connect Demo mode if enabled, else attempt BLE
        if settingsStore.isDemoMode {
            connectDemo(scenario: settingsStore.demoScenario)
        }
    }
    
    deinit {
        snapshotTask?.cancel()
    }
    
    // MARK: - Connection Actions
    
    /// Connects to Demo mode using the chosen scenario.
    public func connectDemo(scenario: SimulatedElm327Transport.Scenario) {
        settingsStore.isDemoMode = true
        settingsStore.demoScenario = scenario
        Task {
            await connectionManager.connectDemo(scenario: scenario)
        }
    }
    
    /// Switches the simulated vehicle scenario in real time.
    public func setDemoScenario(_ scenario: SimulatedElm327Transport.Scenario) {
        settingsStore.demoScenario = scenario
        Task {
            await connectionManager.setDemoScenario(scenario)
        }
    }
    
    /// Connects to a physical BLE adapter (e.g. IOS-VLINK).
    public func connectBle(peripheralName: String? = "IOS-VLINK", peripheralId: UUID? = nil) {
        settingsStore.isDemoMode = false
        Task {
            await connectionManager.connectBle(peripheralName: peripheralName, peripheralId: peripheralId)
        }
    }
    
    /// Toggles Demo mode on or off.
    public func toggleDemoMode() {
        if settingsStore.isDemoMode {
            settingsStore.isDemoMode = false
            connectBle()
        } else {
            connectDemo(scenario: settingsStore.demoScenario)
        }
    }
    
    /// Disconnects from current adapter or simulation.
    public func disconnect() {
        LiveActivityController.shared.end(store: vehicleStore)
        Task {
            await connectionManager.disconnect()
        }
    }
    
    // MARK: - Snapshot Observation
    
    private func startObservingSnapshots() {
        snapshotTask = Task { [weak self, connectionManager] in
            let snapshots = await connectionManager.snapshots
            for await snapshot in snapshots {
                guard let self else { break }
                self.vehicleStore.update(from: snapshot)
                
                // Live Activity coordination (starts on .live, ends on NO_ECU or disconnect)
                if self.vehicleStore.isLive {
                    if self.previousPhase != .live {
                        LiveActivityController.shared.start(
                            vehicleName: self.settingsStore.vehicleName,
                            vehicleEngine: self.settingsStore.vehicleEngine,
                            initialStore: self.vehicleStore
                        )
                    } else {
                        LiveActivityController.shared.update(from: self.vehicleStore)
                    }
                } else if self.previousPhase == .live {
                    LiveActivityController.shared.end(store: self.vehicleStore)
                }
                self.previousPhase = self.vehicleStore.phase
                
                // CarPlay coordination (throttled inside CarPlaySceneDelegate)
                CarPlaySceneDelegate.shared?.update(from: self.vehicleStore)
            }
        }
    }
}
