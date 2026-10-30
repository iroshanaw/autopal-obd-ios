import Foundation

/// Snapshot written to the App Group container by the main app and read by WidgetKit.
/// Widgets never claim live data and display their data age (UI_DESIGN-iOS §8).
nonisolated public struct SharedSnapshot: Codable, Sendable {
    public static let appGroupSuite = "group.com.autopal.obd"
    
    public var vehicleName: String
    public var verdictTitle: String
    public var verdictSeverity: String
    public var coolantTempC: Double?
    public var batteryVoltage: Double?
    public var fuelLevel: Double?
    public var alertHeadline: String?
    public var timestamp: Date
    
    public init(
        vehicleName: String = "Toyota Wigo",
        verdictTitle: String = "Healthy",
        verdictSeverity: String = "healthy",
        coolantTempC: Double? = 90.0,
        batteryVoltage: Double? = 14.1,
        fuelLevel: Double? = 75.0,
        alertHeadline: String? = nil,
        timestamp: Date = .now
    ) {
        self.vehicleName = vehicleName
        self.verdictTitle = verdictTitle
        self.verdictSeverity = verdictSeverity
        self.coolantTempC = coolantTempC
        self.batteryVoltage = batteryVoltage
        self.fuelLevel = fuelLevel
        self.alertHeadline = alertHeadline
        self.timestamp = timestamp
    }
    
    /// Reads the latest snapshot from App Group storage.
    public static func read() -> SharedSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupSuite),
              let data = defaults.data(forKey: "shared_vehicle_snapshot"),
              let snapshot = try? JSONDecoder().decode(SharedSnapshot.self, from: data) else {
            return SharedSnapshot()
        }
        return snapshot
    }
    
    /// Writes the snapshot to App Group storage.
    public func write() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupSuite),
              let data = try? JSONEncoder().encode(self) else {
            return
        }
        defaults.set(data, forKey: "shared_vehicle_snapshot")
    }
    
    /// Human-readable data age to satisfy "Always show data age; never imply live data in widgets".
    public var ageDescription: String {
        let seconds = max(0, Int(-timestamp.timeIntervalSinceNow))
        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let mins = seconds / 60
            return "\(mins)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
