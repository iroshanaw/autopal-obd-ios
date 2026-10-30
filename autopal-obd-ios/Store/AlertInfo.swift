import Foundation
import AutopalCore

public enum AlertSeverity: String, Sendable, Comparable {
    case warning = "warning"
    case critical = "critical"
    
    public static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
        lhs == .warning && rhs == .critical
    }
}

public struct AlertItem: Identifiable, Sendable, Equatable {
    public let id: AlertId
    public let severity: AlertSeverity
    public let headline: String
    public let advice: String
    
    public init(id: AlertId) {
        self.id = id
        switch id {
        case .coolantCritical:
            self.severity = .critical
            self.headline = "Coolant temperature critical"
            self.advice = "Pull over and stop safely. Turn off the engine."
        case .coolantHigh:
            self.severity = .warning
            self.headline = "Coolant temperature high"
            self.advice = "Ease off and switch the A/C off."
        case .coolantRising:
            self.severity = .warning
            self.headline = "Coolant rising rapidly"
            self.advice = "Monitor temperature gauge closely."
        case .chargingLow:
            self.severity = .warning
            self.headline = "Charging system fault"
            self.advice = "Alternator output low. Minimise electrical load."
        case .batteryLow:
            self.severity = .warning
            self.headline = "Battery low at rest"
            self.advice = "Battery charge is low. Start engine to charge."
        case .chargingHigh:
            self.severity = .warning
            self.headline = "High charging voltage"
            self.advice = "Alternator voltage regulator fault detected."
        case .overRev:
            self.severity = .warning
            self.headline = "Engine over-rev"
            self.advice = "Shift up or reduce engine speed."
        case .fuelLow:
            self.severity = .warning
            self.headline = "Fuel level low"
            self.advice = "Find a filling station soon."
        case .fuelCritical:
            self.severity = .critical
            self.headline = "Fuel level critical"
            self.advice = "Refuel immediately to avoid stalling."
        case .trimLeanRich:
            self.severity = .warning
            self.headline = "Fuel trim deviation"
            self.advice = "Air/fuel mixture deviation detected."
        case .trimTotal:
            self.severity = .warning
            self.headline = "Vacuum leak suspected"
            self.advice = "High total fuel trim (+25%). Inspect intake."
        case .newDtcStored:
            self.severity = .warning
            self.headline = "Check Engine fault stored"
            self.advice = "New diagnostic fault code recorded."
        case .newDtcPending:
            self.severity = .warning
            self.headline = "Pending fault code"
            self.advice = "ECU is monitoring an emerging condition."
        case .misfire:
            self.severity = .critical
            self.headline = "Engine misfire detected"
            self.advice = "Ease off and avoid high engine load to protect catalyst."
        }
    }
}
