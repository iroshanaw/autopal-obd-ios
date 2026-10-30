import Foundation

/// An in-memory ELM327 transport that simulates realistic vehicle behavior across multiple scenarios.
/// Powers Demo mode, SwiftUI previews, CarPlay Simulator work, and unit tests.
public final class SimulatedElm327Transport: ObdTransport, @unchecked Sendable {
    public enum Scenario: String, Sendable, CaseIterable {
        case normal
        case ignitionOff
        case overheat
        case chargingFault
        case vacuumLeak
        case misfire
        case dropout
    }

    public let label: String = "SimulatedElm327"

    private let lock = NSLock()
    private var _scenario: Scenario
    private let clock: (any Clock<Duration>)?

    private let stream: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation

    private let linkStream: AsyncStream<LinkState>
    private let linkContinuation: AsyncStream<LinkState>.Continuation

    private var tickCount: Int = 0
    private var isConnected: Bool = false
    private var isClosed: Bool = false

    public init(scenario: Scenario = .normal, clock: (any Clock<Duration>)? = nil) {
        self._scenario = scenario
        self.clock = clock

        var inCont: AsyncStream<Data>.Continuation!
        self.stream = AsyncStream { cont in inCont = cont }
        self.continuation = inCont

        var lCont: AsyncStream<LinkState>.Continuation!
        self.linkStream = AsyncStream { cont in lCont = cont }
        self.linkContinuation = lCont
    }

    public var scenario: Scenario {
        lock.withLock { _scenario }
    }

    public func setScenario(_ newScenario: Scenario) {
        lock.withLock {
            _scenario = newScenario
            tickCount = 0
        }
    }

    public var incoming: AsyncStream<Data> {
        stream
    }

    public var linkState: AsyncStream<LinkState> {
        linkStream
    }

    public func connect() async throws {
        lock.withLock {
            isConnected = true
            tickCount = 0
        }
        linkContinuation.yield(.connected)
    }

    public func close() async {
        lock.withLock {
            isConnected = false
            isClosed = true
        }
        linkContinuation.yield(.disconnected)
        linkContinuation.finish()
        continuation.finish()
    }

    public func write(_ bytes: Data) async throws {
        guard let rawStr = String(data: bytes, encoding: .utf8) else {
            return
        }

        let cmd = rawStr.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = cmd.uppercased().replacingOccurrences(of: " ", with: "")

        let (reply, shouldDisconnect) = lock.withLock {
            generateReply(for: normalized)
        }

        if shouldDisconnect {
            linkContinuation.yield(.disconnected)
            continuation.yield(Data("STOPPED\r\r>".utf8))
            return
        }

        if let reply {
            let formatted = reply + "\r\r>"
            continuation.yield(Data(formatted.utf8))
        }
    }

    // MARK: - Reply Generation (Called within lock)

    private func generateReply(for cmd: String) -> (reply: String?, disconnect: Bool) {
        // Mode 01 PID with optional CAN hint '1' (e.g. 010C1 -> 010C)
        var cleanCmd = cmd
        if cleanCmd.count == 5 && cleanCmd.hasPrefix("01") && cleanCmd.hasSuffix("1") {
            cleanCmd = String(cleanCmd.prefix(4))
        }

        // Advance simulation tick on primary RPM poll
        if cleanCmd == "010C" {
            tickCount += 1
        }

        // Dropout scenario: disconnect after 3 cycles
        if _scenario == .dropout && tickCount >= 3 {
            return (nil, true)
        }

        // AT commands
        if cleanCmd == "ATZ" {
            return ("ELM327 v1.5", false)
        }
        if cleanCmd.hasPrefix("AT") {
            return (handleAtCommand(cleanCmd), false)
        }

        // Mode 01 Supported PIDs discovery
        if cleanCmd == "0100" {
            if _scenario == .ignitionOff {
                return ("UNABLE TO CONNECT", false)
            }
            return ("4100BE3FA813", false)
        }
        if cleanCmd == "0120" {
            return ("41209007B015", false)
        }
        if cleanCmd == "0140" {
            return ("4140FED08000", false)
        }
        if cleanCmd == "0160" {
            return ("NO DATA", false)
        }

        // Mode 09: VIN
        if cleanCmd == "0902" {
            if _scenario == .ignitionOff {
                return ("NO DATA", false)
            }
            // Multi-frame CAN format for 1HGCM82633A004352
            return ("014\r0:490201314847\r1:434D3832363333\r2:41303034333532", false)
        }

        // Mode 01: Readiness
        if cleanCmd == "0101" {
            if _scenario == .ignitionOff {
                return ("NO DATA", false)
            }
            if _scenario == .misfire {
                // MIL on, 1 DTC, spark engine, misfire monitor active/incomplete
                return ("41018107E501", false)
            }
            // MIL off, 0 DTCs, spark engine, all complete
            return ("41010007E500", false)
        }

        // Mode 03: Stored DTCs
        if cleanCmd == "03" {
            if _scenario == .ignitionOff {
                return ("NO DATA", false)
            }
            if _scenario == .misfire {
                return ("43010300", false) // P0300
            }
            return ("4300", false)
        }

        // Mode 07: Pending DTCs
        if cleanCmd == "07" {
            if _scenario == .ignitionOff {
                return ("NO DATA", false)
            }
            return ("4700", false)
        }

        // In ignitionOff, any subsequent OBD poll fails
        if _scenario == .ignitionOff {
            return ("UNABLE TO CONNECT", false)
        }

        // Mode 01 Telemetry PIDs
        let reply = handleMode01Pid(cleanCmd)
        return (reply, false)
    }

    private func handleAtCommand(_ cmd: String) -> String {
        switch cmd {
        case "ATE0", "ATE1", "ATL0", "ATL1", "ATS0", "ATS1", "ATH0", "ATH1", "ATAT1", "ATAT0", "ATAT2":
            return "OK"
        case "ATSP0", "ATSP6", "ATSP7", "ATSP8":
            return "OK"
        case "ATDPN":
            return "A6" // ISO 15765-4 CAN 11/500
        case "ATRV":
            return formatAdapterVoltage()
        default:
            return "OK"
        }
    }

    private func formatAdapterVoltage() -> String {
        switch _scenario {
        case .ignitionOff:
            return "12.4V"
        case .chargingFault:
            return "11.6V"
        default:
            return "14.1V"
        }
    }

    private func handleMode01Pid(_ pid: String) -> String {
        let t = Double(tickCount)

        switch pid {
        case "010C": // RPM
            return encodeRpm(computeRpm(t: t))

        case "010D": // Speed
            return encodeSpeed(computeSpeed(t: t))

        case "0105": // Coolant Temp
            return encodeTemp(pid: "05", computeCoolant(t: t))

        case "0111": // Throttle
            let thr = 18.0 + 8.0 * sin(t * 0.2)
            return encodePercentage(pid: "11", thr)

        case "0104": // Engine Load
            let load = 30.0 + 10.0 * sin(t * 0.2)
            return encodePercentage(pid: "04", load)

        case "010F": // Intake Air Temp
            return encodeTemp(pid: "0F", 35.0)

        case "015C": // Engine Oil Temp
            let oil = (_scenario == .overheat) ? 121.0 : 92.0
            return encodeTemp(pid: "5C", oil)

        case "0142": // Control Module Voltage
            let v = computeVoltage(t: t)
            return encodeVoltage(v)

        case "0110": // MAF Air Flow
            let maf = 5.0 + 3.0 * sin(t * 0.2)
            return encodeMaf(maf)

        case "0106": // Short Term Fuel Trim
            let stft = computeStft(t: t)
            return encodeTrim(pid: "06", stft)

        case "0107": // Long Term Fuel Trim
            let ltft = computeLtft(t: t)
            return encodeTrim(pid: "07", ltft)

        case "012F": // Fuel Tank Level
            return encodePercentage(pid: "2F", 65.0)

        case "010A": // Fuel Pressure
            return encodeFuelPressure(300.0)

        case "0146": // Ambient Air Temp
            return encodeTemp(pid: "46", 25.0)

        default:
            return "NO DATA"
        }
    }

    // MARK: - Scenario-Specific Value Computations

    private func computeRpm(t: Double) -> Double {
        switch _scenario {
        case .normal, .overheat, .chargingFault, .vacuumLeak, .dropout:
            return 850.0 + 450.0 * (1.0 + sin(t * 0.25))
        case .misfire:
            // Stumbling idle with roughness
            return 750.0 + 150.0 * sin(t * 0.8)
        case .ignitionOff:
            return 0.0
        }
    }

    private func computeSpeed(t: Double) -> Double {
        switch _scenario {
        case .ignitionOff:
            return 0.0
        default:
            return max(0.0, 35.0 + 20.0 * sin(t * 0.2))
        }
    }

    private func computeCoolant(t: Double) -> Double {
        switch _scenario {
        case .overheat:
            return 119.0
        default:
            return 90.0
        }
    }

    private func computeVoltage(t: Double) -> Double {
        switch _scenario {
        case .chargingFault:
            return 11.6
        default:
            return 14.1
        }
    }

    private func computeStft(t: Double) -> Double {
        switch _scenario {
        case .vacuumLeak:
            return 18.0
        default:
            return 0.5 * sin(t * 0.3)
        }
    }

    private func computeLtft(t: Double) -> Double {
        switch _scenario {
        case .vacuumLeak:
            return 10.0
        default:
            return 1.0
        }
    }

    // MARK: - OBD Encoding Helpers

    private func encodeRpm(_ rpm: Double) -> String {
        let raw = min(65535, max(0, Int(rpm * 4.0)))
        let a = (raw >> 8) & 0xFF
        let b = raw & 0xFF
        return String(format: "410C%02X%02X", a, b)
    }

    private func encodeSpeed(_ kmh: Double) -> String {
        let val = min(255, max(0, Int(kmh)))
        return String(format: "410D%02X", val)
    }

    private func encodePercentage(pid: String, _ pct: Double) -> String {
        let val = min(255, max(0, Int(pct * 255.0 / 100.0)))
        return String(format: "41%@%02X", pid, val)
    }

    private func encodeTemp(pid: String, _ c: Double) -> String {
        let val = min(255, max(0, Int(c + 40.0)))
        return String(format: "41%@%02X", pid, val)
    }

    private func encodeVoltage(_ v: Double) -> String {
        let mv = min(65535, max(0, Int(v * 1000.0)))
        let a = (mv >> 8) & 0xFF
        let b = mv & 0xFF
        return String(format: "4142%02X%02X", a, b)
    }

    private func encodeTrim(pid: String, _ pct: Double) -> String {
        let val = min(255, max(0, Int((pct * 1.28) + 128.0)))
        return String(format: "41%@%02X", pid, val)
    }

    private func encodeMaf(_ gs: Double) -> String {
        let raw = min(65535, max(0, Int(gs * 100.0)))
        let a = (raw >> 8) & 0xFF
        let b = raw & 0xFF
        return String(format: "4110%02X%02X", a, b)
    }

    private func encodeFuelPressure(_ kpa: Double) -> String {
        let val = min(255, max(0, Int(kpa / 3.0)))
        return String(format: "410A%02X", val)
    }
}
