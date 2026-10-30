import ActivityKit
import Foundation

/// Activity attributes defining static configuration and dynamic state
/// for the Autopal active driving Live Activity (UI_DESIGN-iOS §8).
nonisolated public struct DriveActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var verdictTitle: String
        public var verdictSeverity: String
        public var coolantTempC: Double?
        public var batteryVoltage: Double?
        public var engineRpm: Double?
        public var fuelLevel: Double?
        public var alertHeadline: String?
        public var alertAdvice: String?
        public var timestamp: Date

        public init(
            verdictTitle: String,
            verdictSeverity: String,
            coolantTempC: Double? = nil,
            batteryVoltage: Double? = nil,
            engineRpm: Double? = nil,
            fuelLevel: Double? = nil,
            alertHeadline: String? = nil,
            alertAdvice: String? = nil,
            timestamp: Date = .now
        ) {
            self.verdictTitle = verdictTitle
            self.verdictSeverity = verdictSeverity
            self.coolantTempC = coolantTempC
            self.batteryVoltage = batteryVoltage
            self.engineRpm = engineRpm
            self.fuelLevel = fuelLevel
            self.alertHeadline = alertHeadline
            self.alertAdvice = alertAdvice
            self.timestamp = timestamp
        }
    }

    public var vehicleName: String
    public var vehicleEngine: String

    public init(vehicleName: String = "Toyota Wigo", vehicleEngine: String = "1KR-VE 1.0L") {
        self.vehicleName = vehicleName
        self.vehicleEngine = vehicleEngine
    }
}
