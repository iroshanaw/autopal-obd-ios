import SwiftUI
import WidgetKit
import AutopalCore

/// Presentation severity for UI badges and card styling.
public enum VerdictSeverity: Sendable, Equatable {
    case healthy
    case attention
    case critical
    case notConnected
}

/// Overall vehicle health verdict (UI_DESIGN-iOS §1 & §4).
public enum HealthVerdict: String, Sendable, Equatable {
    case healthy = "HEALTHY"
    case serviceSoon = "SERVICE_SOON"
    case stopAndCheck = "STOP_AND_CHECK"
    case notConnected = "NOT_CONNECTED"
    
    public var title: String {
        switch self {
        case .healthy: return "Healthy"
        case .serviceSoon: return "Service soon"
        case .stopAndCheck: return "Stop and check"
        case .notConnected: return "Not connected"
        }
    }
    
    public var severity: VerdictSeverity {
        switch self {
        case .healthy: return .healthy
        case .serviceSoon: return .attention
        case .stopAndCheck: return .critical
        case .notConnected: return .notConnected
        }
    }
    
    public var badgeLabel: String {
        switch self {
        case .healthy: return "HEALTHY"
        case .serviceSoon: return "ATTENTION"
        case .stopAndCheck: return "STOP"
        case .notConnected: return "OFFLINE"
        }
    }
}

/// Main observable store holding live vehicle readings and state.
/// Observed by UI views, CarPlay, and the Live Activity controller.
@Observable
@MainActor
public final class VehicleStore {
    public var phase: ConnectionPhase = .disconnected
    public var readings: [String: Double] = [:]
    public var activeAlerts: [AlertItem] = []
    public var storedDtcs: [String] = []
    public var pendingDtcs: [String] = []
    public var readiness: ReadinessStatus?
    public var vin: String?
    public var protocolName: String?
    public var elmVersion: String?
    public var adapterVoltage: Double?
    public var lastUpdated: Date?
    public var verdict: HealthVerdict = .notConnected
    
    private let appGroupSuite: String
    private var previousVerdict: HealthVerdict = .notConnected
    private var previousAlertCount: Int = 0
    
    public init(appGroupSuite: String = "group.com.autopal.obd") {
        self.appGroupSuite = appGroupSuite
    }
    
    // MARK: - Computed Properties for UI
    
    public var isLive: Bool { phase == .live }
    public var isNoEcu: Bool { phase == .noEcu }
    public var isConnected: Bool { phase != .disconnected }
    
    public var rpm: Double? { readings["RPM"] }
    public var engineRpm: Double? { rpm }
    public var speed: Double? { readings["SPEED"] }
    public var coolantTemp: Double? { readings["COOLANT_TEMP"] }
    public var coolantTempC: Double? { coolantTemp }
    public var intakeTemp: Double? { readings["INTAKE_TEMP"] }
    public var batteryVoltage: Double? { readings["CONTROL_MODULE_VOLTAGE"] ?? readings["ADAPTER_VOLTAGE"] ?? adapterVoltage }
    public var fuelLevel: Double? { readings["FUEL_LEVEL"] }
    public var engineLoad: Double? { readings["ENGINE_LOAD"] }
    public var throttle: Double? { readings["THROTTLE"] }
    public var stft: Double? { readings["SHORT_FUEL_TRIM_B1"] }
    public var ltft: Double? { readings["LONG_FUEL_TRIM_B1"] }
    public var maf: Double? { readings["MAF"] }
    
    /// Most critical alert currently active, if any.
    public var primaryAlert: AlertItem? {
        if let critical = activeAlerts.first(where: { $0.severity == .critical }) {
            return critical
        }
        return activeAlerts.first(where: { $0.severity == .warning })
    }
    
    // MARK: - Update from Core Snapshot
    
    public func update(from snapshot: VehicleSnapshot) {
        self.phase = snapshot.phase
        self.readings = snapshot.readings
        self.activeAlerts = snapshot.activeAlerts.map(AlertItem.init)
        self.storedDtcs = snapshot.storedDtcs
        self.pendingDtcs = snapshot.pendingDtcs
        self.readiness = snapshot.readiness
        self.vin = snapshot.vin
        self.protocolName = snapshot.protocolId
        self.elmVersion = snapshot.adapterVersion
        self.adapterVoltage = snapshot.readings["ADAPTER_VOLTAGE"]
        self.lastUpdated = Date()
        
        self.verdict = computeVerdict()
        writeSharedSnapshot()
    }
    
    private func computeVerdict() -> HealthVerdict {
        guard phase != .disconnected else {
            return .notConnected
        }
        if phase == .noEcu {
            return .notConnected
        }
        
        // Critical alerts or severe DTCs
        if activeAlerts.contains(where: { $0.severity == .critical }) {
            return .stopAndCheck
        }
        // Warning alerts or any stored DTCs
        if activeAlerts.contains(where: { $0.severity == .warning }) || !storedDtcs.isEmpty {
            return .serviceSoon
        }
        
        return .healthy
    }
    
    // MARK: - Shared Snapshot for Widgets
    
    private func writeSharedSnapshot() {
        let snapshot = SharedSnapshot(
            vehicleName: "Toyota Wigo",
            verdictTitle: verdict.title,
            verdictSeverity: verdict.severity == .healthy ? "healthy" : (verdict.severity == .attention ? "warning" : (verdict.severity == .critical ? "critical" : "notConnected")),
            coolantTempC: coolantTemp,
            batteryVoltage: batteryVoltage,
            fuelLevel: fuelLevel,
            alertHeadline: primaryAlert?.headline,
            timestamp: .now
        )
        snapshot.write()
        
        // Reload widget timeline only when verdict or alert changes to preserve widget budget
        if verdict != previousVerdict || activeAlerts.count != previousAlertCount {
            previousVerdict = verdict
            previousAlertCount = activeAlerts.count
            WidgetCenter.shared.reloadTimelines(ofKind: "VehicleHealthWidget")
        }
    }
}
