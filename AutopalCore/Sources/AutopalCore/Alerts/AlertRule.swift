import Foundation

public enum AlertId: String, Sendable, CaseIterable {
    case coolantHigh = "COOLANT_HIGH"
    case coolantCritical = "COOLANT_CRITICAL"
    case coolantRising = "COOLANT_RISING"
    case chargingLow = "CHARGING_LOW"
    case batteryLow = "BATTERY_LOW"
    case chargingHigh = "CHARGING_HIGH"
    case overRev = "OVER_REV"
    case fuelLow = "FUEL_LOW"
    case fuelCritical = "FUEL_CRITICAL"
    case trimLeanRich = "TRIM_LEAN_RICH"
    case trimTotal = "TRIM_TOTAL"
    case newDtcStored = "NEW_DTC_STORED"
    case newDtcPending = "NEW_DTC_PENDING"
    case misfire = "MISFIRE"
}

public struct VehicleProfile: Sendable, Equatable {
    public let name: String
    public let redlineRpm: Double

    public init(name: String, redlineRpm: Double) {
        self.name = name
        self.redlineRpm = redlineRpm
    }

    public static let petrol6500 = VehicleProfile(name: "petrol6500", redlineRpm: 6500)
    public static let diesel4500 = VehicleProfile(name: "diesel4500", redlineRpm: 4500)
}

public struct AlertInput: Sendable {
    public let timestampMs: Int64
    public let rpm: Double?
    public let speed: Double?
    public let coolant: Double?
    public let voltage: Double?
    public let fuel: Double?
    public let stft: Double?
    public let ltft: Double?
    public let dtcsStored: [String]
    public let dtcsPending: [String]

    public init(
        timestampMs: Int64,
        rpm: Double? = nil,
        speed: Double? = nil,
        coolant: Double? = nil,
        voltage: Double? = nil,
        fuel: Double? = nil,
        stft: Double? = nil,
        ltft: Double? = nil,
        dtcsStored: [String] = [],
        dtcsPending: [String] = []
    ) {
        self.timestampMs = timestampMs
        self.rpm = rpm
        self.speed = speed
        self.coolant = coolant
        self.voltage = voltage
        self.fuel = fuel
        self.stft = stft
        self.ltft = ltft
        self.dtcsStored = dtcsStored
        self.dtcsPending = dtcsPending
    }
}

public struct AlertEvaluationResult: Sendable, Equatable {
    public let raised: Set<AlertId>
    public let active: Set<AlertId>

    public init(raised: Set<AlertId>, active: Set<AlertId>) {
        self.raised = raised
        self.active = active
    }
}

/// Evaluates vehicle telemetry against alert thresholds, sustain times, and hysteresis.
public struct AlertEngine: Sendable {
    public let profile: VehicleProfile

    private var activeAlerts = Set<AlertId>()
    private var conditionStartTimes: [AlertId: Int64] = [:]

    // Coolant rise tracking
    private var coolantHistory: [(tMs: Int64, temp: Double)] = []

    // DTC tracking
    private var seenStoredDtcs = Set<String>()
    private var seenPendingDtcs = Set<String>()
    private var isFirstEvaluation = true

    public init(profile: VehicleProfile) {
        self.profile = profile
    }

    public mutating func evaluate(input: AlertInput) -> AlertEvaluationResult {
        let t = input.timestampMs
        var newlyRaised = Set<AlertId>()
        var currentActive = activeAlerts

        // 1. Coolant Critical: >= 118 °C sustained for 5000 ms, hysteresis < 115 °C
        let coolantCritCond = (input.coolant ?? 0) >= 118.0
        checkSustained(
            alert: .coolantCritical,
            condition: coolantCritCond,
            clearCondition: (input.coolant ?? 0) < 115.0,
            now: t,
            sustainMs: 5000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 2. Coolant High: >= 112 °C sustained for 10000 ms, hysteresis < 108 °C
        let coolantHighCond = (input.coolant ?? 0) >= 112.0
        checkSustained(
            alert: .coolantHigh,
            condition: coolantHighCond,
            clearCondition: (input.coolant ?? 0) < 108.0,
            now: t,
            sustainMs: 10000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 3. Coolant Rising: rate >= 2.0 °C/min sustained for 180,000 ms (3 min) when above 90°C and speed > 0
        if let coolant = input.coolant {
            coolantHistory.append((tMs: t, temp: coolant))
            // Prune history older than 4 minutes
            coolantHistory.removeAll { t - $0.tMs > 240000 }

            if let first = coolantHistory.first, t - first.tMs >= 180000 {
                let dtMinutes = Double(t - first.tMs) / 60000.0
                let dTemp = coolant - first.temp
                let ratePerMin = dTemp / dtMinutes

                // Must be above normal warm band (initial temp >= 90) to distinguish from warmup
                let isAboveWarmup = first.temp >= 90.0
                let isRisingRapidly = isAboveWarmup && ratePerMin >= 2.0

                checkSustained(
                    alert: .coolantRising,
                    condition: isRisingRapidly,
                    clearCondition: ratePerMin < 1.0 || (input.speed ?? 0) <= 0,
                    now: t,
                    sustainMs: 0, // Rate already computed over the window
                    active: &currentActive,
                    raised: &newlyRaised
                )
            }
        }

        // 4. Charging Low: voltage <= 13.0 V sustained for 20000 ms when engine running (> 400 rpm), hysteresis >= 13.2 V
        let isEngineRunning = (input.rpm ?? 0) > 400
        let chargingLowCond = isEngineRunning && (input.voltage ?? 99) <= 13.0
        let chargingLowClear = !isEngineRunning || (input.voltage ?? 0) >= 13.2
        checkSustained(
            alert: .chargingLow,
            condition: chargingLowCond,
            clearCondition: chargingLowClear,
            now: t,
            sustainMs: 20000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 5. Battery Low: voltage < 12.0 V sustained for 30000 ms when engine off (<= 0 rpm), hysteresis >= 12.2 V
        let isEngineOff = (input.rpm ?? 0) <= 0
        let batteryLowCond = isEngineOff && (input.voltage ?? 99) < 12.0
        let batteryLowClear = !isEngineOff || (input.voltage ?? 0) >= 12.2
        checkSustained(
            alert: .batteryLow,
            condition: batteryLowCond,
            clearCondition: batteryLowClear,
            now: t,
            sustainMs: 30000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 6. Charging High: voltage >= 15.2 V sustained for 10000 ms when engine running, hysteresis < 15.0 V
        let chargingHighCond = isEngineRunning && (input.voltage ?? 0) >= 15.2
        let chargingHighClear = !isEngineRunning || (input.voltage ?? 0) < 15.0
        checkSustained(
            alert: .chargingHigh,
            condition: chargingHighCond,
            clearCondition: chargingHighClear,
            now: t,
            sustainMs: 10000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 7. Over-rev: rpm >= 92% of redline sustained for 3000 ms, hysteresis < threshold - 500
        let overRevThreshold = profile.redlineRpm * 0.92
        let overRevCond = (input.rpm ?? 0) >= overRevThreshold
        let overRevClear = (input.rpm ?? 0) < (overRevThreshold - 500)
        checkSustained(
            alert: .overRev,
            condition: overRevCond,
            clearCondition: overRevClear,
            now: t,
            sustainMs: 3000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 8. Fuel Critical: fuel <= 7.0 % sustained for 10000 ms, hysteresis > 7.0 %
        let fuelCritCond = (input.fuel != nil) && input.fuel! <= 7.0
        checkSustained(
            alert: .fuelCritical,
            condition: fuelCritCond,
            clearCondition: (input.fuel ?? 100) > 7.0,
            now: t,
            sustainMs: 10000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 9. Fuel Low: fuel <= 15.0 % sustained for 10000 ms, hysteresis >= 18.0 %
        let fuelLowCond = (input.fuel != nil) && input.fuel! <= 15.0
        checkSustained(
            alert: .fuelLow,
            condition: fuelLowCond,
            clearCondition: (input.fuel ?? 0) >= 18.0,
            now: t,
            sustainMs: 10000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 10. Trim Lean/Rich: warm engine (coolant >= 80 °C), abs(ltft) >= 10.0 % sustained for 60000 ms, hysteresis < 8.0 %
        let isEngineWarm = (input.coolant ?? 0) >= 80.0
        let trimLeanRichCond = isEngineWarm && abs(input.ltft ?? 0) >= 10.0
        let trimLeanRichClear = !isEngineWarm || abs(input.ltft ?? 0) < 8.0
        checkSustained(
            alert: .trimLeanRich,
            condition: trimLeanRichCond,
            clearCondition: trimLeanRichClear,
            now: t,
            sustainMs: 60000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 11. Trim Total: warm engine, abs(stft + ltft) >= 25.0 % sustained for 30000 ms, hysteresis < 20.0 %
        let totalTrim = abs((input.stft ?? 0) + (input.ltft ?? 0))
        let trimTotalCond = isEngineWarm && totalTrim >= 25.0
        let trimTotalClear = !isEngineWarm || totalTrim < 20.0
        checkSustained(
            alert: .trimTotal,
            condition: trimTotalCond,
            clearCondition: trimTotalClear,
            now: t,
            sustainMs: 30000,
            active: &currentActive,
            raised: &newlyRaised
        )

        // 12. DTCs: Stored & Pending
        var newStored = false
        for dtc in input.dtcsStored {
            if !seenStoredDtcs.contains(dtc) {
                seenStoredDtcs.insert(dtc)
                if !isFirstEvaluation || !input.dtcsStored.isEmpty {
                    newStored = true
                }
            }
        }
        if newStored {
            currentActive.insert(.newDtcStored)
            newlyRaised.insert(.newDtcStored)
        }

        var newPending = false
        for dtc in input.dtcsPending {
            if !seenPendingDtcs.contains(dtc) {
                seenPendingDtcs.insert(dtc)
                if !isFirstEvaluation || !input.dtcsPending.isEmpty {
                    newPending = true
                }
            }
        }
        if newPending {
            currentActive.insert(.newDtcPending)
            newlyRaised.insert(.newDtcPending)
        }

        // Misfire check (P0300 - P0312 in stored DTCs)
        let hasMisfire = input.dtcsStored.contains { code in
            guard code.hasPrefix("P03") && code.count == 5 else { return false }
            let suffix = String(code.dropFirst(3))
            guard let num = Int(suffix) else { return false }
            return num >= 0 && num <= 12
        }
        if hasMisfire {
            currentActive.insert(.misfire)
            newlyRaised.insert(.misfire)
        }

        isFirstEvaluation = false

        // Family suppression: highest severity in family wins
        // Coolant family: COOLANT_CRITICAL suppresses COOLANT_HIGH
        if currentActive.contains(.coolantCritical) {
            currentActive.remove(.coolantHigh)
            newlyRaised.remove(.coolantHigh)
        }
        // Fuel family: FUEL_CRITICAL suppresses FUEL_LOW
        if currentActive.contains(.fuelCritical) {
            currentActive.remove(.fuelLow)
            newlyRaised.remove(.fuelLow)
        }

        self.activeAlerts = currentActive
        return AlertEvaluationResult(raised: newlyRaised, active: currentActive)
    }

    private mutating func checkSustained(
        alert: AlertId,
        condition: Bool,
        clearCondition: Bool,
        now: Int64,
        sustainMs: Int64,
        active: inout Set<AlertId>,
        raised: inout Set<AlertId>
    ) {
        if condition {
            if conditionStartTimes[alert] == nil {
                conditionStartTimes[alert] = now
            }
            let startTime = conditionStartTimes[alert]!
            if now - startTime >= sustainMs {
                if !active.contains(alert) {
                    active.insert(alert)
                    raised.insert(alert)
                }
            }
        } else {
            conditionStartTimes.removeValue(forKey: alert)
            if clearCondition {
                active.remove(alert)
            }
        }
    }
}
