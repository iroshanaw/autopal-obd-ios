import Foundation

/// Defines OBD polling tiers, intervals and priorities.
public enum PollTier: Sendable {
    /// Fast tier: RPM, speed, throttle, engine load. Polled every cycle.
    public static let fastPids: [String] = ["010C", "010D", "0111", "0104"]

    /// Medium tier (2 s): coolant, intake, oil temp, module voltage, MAF, short trim, long trim.
    public static let mediumPids: [String] = ["0105", "010F", "015C", "0142", "0110", "0106", "0107"]

    /// Slow tier (30 s): fuel level, fuel pressure, ambient temp.
    public static let slowPids: [String] = ["012F", "010A", "0146"]

    /// Diagnostic tier: 0101 (readiness & MIL, 30 s), 03 & 07 (stored & pending DTCs, 60 s).
    public static let diagPids30: [String] = ["0101"]
    public static let diagPids60: [String] = ["03", "07"]

    /// Fallback command for voltage if 0142 is not supported.
    public static let fallbackVoltage: String = "ATRV"
}

/// Dynamic poll scheduler that prioritises PIDs and drops unavailable commands.
public struct PollScheduler: Sendable {
    public private(set) var supportedPids: Set<UInt8>
    public private(set) var isCan: Bool
    public private(set) var hintEnabled: Bool

    private var noDataCounts: [String: Int] = [:]
    private var droppedPids: Set<String> = []

    private var lastMediumTime: Int64
    private var lastSlowTime: Int64
    private var lastDiag30Time: Int64
    private var lastDiag60Time: Int64

    public init(
        supportedPids: Set<UInt8>,
        isCan: Bool,
        hintEnabled: Bool = false,
        initialFullCycle: Bool = false
    ) {
        self.supportedPids = supportedPids
        self.isCan = isCan
        self.hintEnabled = hintEnabled

        if initialFullCycle {
            self.lastMediumTime = -2000
            self.lastSlowTime = -30000
            self.lastDiag30Time = -30000
            self.lastDiag60Time = -60000
        } else {
            self.lastMediumTime = 0
            self.lastSlowTime = 0
            self.lastDiag30Time = 0
            self.lastDiag60Time = 0
        }
    }

    public mutating func enableHint(_ enable: Bool) {
        self.hintEnabled = enable
    }

    public func isDropped(_ command: String) -> Bool {
        droppedPids.contains(baseCommand(command))
    }

    public mutating func nextBatch(elapsedMs: Int64) -> [String] {
        var batch: [String] = []

        // FAST tier: every tick
        for pid in PollTier.fastPids {
            if isCommandAvailable(pid) {
                batch.append(formatCommand(pid))
            }
        }

        // MEDIUM tier: every 2000 ms
        if elapsedMs - lastMediumTime >= 2000 {
            lastMediumTime = elapsedMs
            for pid in PollTier.mediumPids {
                if isCommandAvailable(pid) {
                    batch.append(formatCommand(pid))
                }
            }
        }

        // SLOW tier: every 30000 ms
        if elapsedMs - lastSlowTime >= 30000 {
            lastSlowTime = elapsedMs
            for pid in PollTier.slowPids {
                if isCommandAvailable(pid) {
                    batch.append(formatCommand(pid))
                }
            }
            // If control module voltage (0142) is unsupported, fallback to ATRV
            if !supportedPids.contains(0x42) && !isDropped(PollTier.fallbackVoltage) {
                batch.append(PollTier.fallbackVoltage)
            }
        }

        // DIAG tier: 0101 every 30000 ms, 03 & 07 every 60000 ms
        if elapsedMs - lastDiag30Time >= 30000 {
            lastDiag30Time = elapsedMs
            for cmd in PollTier.diagPids30 {
                if !isDropped(cmd) {
                    batch.append(cmd)
                }
            }
        }

        if elapsedMs - lastDiag60Time >= 60000 {
            lastDiag60Time = elapsedMs
            for cmd in PollTier.diagPids60 {
                if !isDropped(cmd) {
                    batch.append(cmd)
                }
            }
        }

        return batch
    }

    private func isCommandAvailable(_ command: String) -> Bool {
        let base = baseCommand(command)
        if droppedPids.contains(base) {
            return false
        }
        if base.hasPrefix("01") && base.count == 4 {
            let hex = String(base.dropFirst(2))
            if let byte = Hex.parseUInt8(hex) {
                return supportedPids.contains(byte)
            }
        }
        return true
    }

    private func formatCommand(_ pid: String) -> String {
        if isCan && hintEnabled && pid.hasPrefix("01") && pid.count == 4 {
            return pid + "1"
        }
        return pid
    }

    public mutating func recordResult(command: String, reply: ElmReply) {
        let base = baseCommand(command)
        if reply == .noData {
            let count = (noDataCounts[base] ?? 0) + 1
            noDataCounts[base] = count
            if count >= 3 {
                droppedPids.insert(base)
            }
        } else if case .ok = reply {
            noDataCounts[base] = 0
        }
    }

    private func baseCommand(_ command: String) -> String {
        var trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if isCan && trimmed.hasPrefix("01") && trimmed.count == 5 && trimmed.hasSuffix("1") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed
    }
}
