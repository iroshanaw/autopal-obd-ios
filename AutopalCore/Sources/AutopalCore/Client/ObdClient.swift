import Foundation

public enum ConnectionPhase: String, Sendable, Equatable {
    case disconnected = "DISCONNECTED"
    case connecting = "CONNECTING"
    case initializing = "INITIALIZING"
    case discovering = "DISCOVERING"
    case live = "LIVE"
    case noEcu = "NO_ECU"
}

public struct VehicleSnapshot: Sendable, Equatable {
    public var phase: ConnectionPhase
    public var adapterVersion: String?
    public var protocolId: String?
    public var isCan: Bool
    public var hintEnabled: Bool
    public var vin: String?
    public var supportedPids: Set<UInt8>
    public var readings: [String: Double]
    public var readiness: ReadinessStatus?
    public var storedDtcs: [String]
    public var pendingDtcs: [String]
    public var activeAlerts: Set<AlertId>
    public var timestampMs: Int64

    public init(
        phase: ConnectionPhase = .disconnected,
        adapterVersion: String? = nil,
        protocolId: String? = nil,
        isCan: Bool = false,
        hintEnabled: Bool = false,
        vin: String? = nil,
        supportedPids: Set<UInt8> = [],
        readings: [String: Double] = [:],
        readiness: ReadinessStatus? = nil,
        storedDtcs: [String] = [],
        pendingDtcs: [String] = [],
        activeAlerts: Set<AlertId> = [],
        timestampMs: Int64 = 0
    ) {
        self.phase = phase
        self.adapterVersion = adapterVersion
        self.protocolId = protocolId
        self.isCan = isCan
        self.hintEnabled = hintEnabled
        self.vin = vin
        self.supportedPids = supportedPids
        self.readings = readings
        self.readiness = readiness
        self.storedDtcs = storedDtcs
        self.pendingDtcs = pendingDtcs
        self.activeAlerts = activeAlerts
        self.timestampMs = timestampMs
    }
}

public actor ObdClient {
    public private(set) var snapshot: VehicleSnapshot
    public let session: ElmSession
    public let trafficLog: TrafficLog
    public let clock: any Clock<Duration>
    public let profile: VehicleProfile

    private var pollScheduler: PollScheduler?
    private var alertEngine: AlertEngine
    private var elapsedMs: Int64 = 0

    public init(
        transport: any ObdTransport,
        clock: any Clock<Duration>,
        profile: VehicleProfile = .petrol6500,
        adapter: String = "ELM327",
        transportType: String = "BLE",
        device: String = "IOS-VLINK",
        appVersion: String = "0.1.0"
    ) {
        self.clock = clock
        self.profile = profile
        self.snapshot = VehicleSnapshot(phase: .disconnected)
        let log = TrafficLog(
            adapter: adapter,
            transport: transportType,
            device: device,
            appVersion: appVersion,
            clock: clock
        )
        self.trafficLog = log
        self.session = ElmSession(transport: transport, clock: clock, trafficLog: log)
        self.alertEngine = AlertEngine(profile: profile)
    }

    public var currentSnapshot: VehicleSnapshot {
        snapshot
    }

    public func trafficLogExport(isoDate: String = "2026-10-29T12:00:00Z") async -> String {
        await trafficLog.export(isoDate: isoDate)
    }

    private func sendCommand(_ command: String) async -> ElmReply {
        do {
            return try await session.send(command)
        } catch {
            return .error(.other("transport error"))
        }
    }

    /// Runs the connection and discovery sequence.
    public func start() async {
        snapshot.phase = .initializing

        // 1. ATZ
        let atzReply = await sendCommand("ATZ")
        if case .ok(let lines) = atzReply {
            for line in lines {
                if line.contains("ELM327") {
                    snapshot.adapterVersion = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }

        // 2. ATE0
        _ = await sendCommand("ATE0")

        // 3. Optional setup commands
        _ = await sendCommand("ATL0")
        _ = await sendCommand("ATS0")
        _ = await sendCommand("ATH0")
        _ = await sendCommand("ATAT1")
        _ = await sendCommand("ATSP0")

        // 4. ATRV
        let atrvReply = await sendCommand("ATRV")
        if case .ok(let lines) = atrvReply {
            if let voltage = PidCatalog.decode(command: "ATRV", lines: lines) {
                snapshot.readings["ADAPTER_VOLTAGE"] = voltage
            }
        }

        snapshot.phase = .discovering

        // 5. Query 0100
        let reply0100 = await sendCommand("0100")
        guard case .ok(let lines0100) = reply0100 else {
            snapshot.phase = .noEcu
            return
        }

        // Check if 0100 has valid response
        let supported01_20 = SupportedPids.parseReplyLines(lines0100, range: 0x00)
        guard !supported01_20.isEmpty else {
            snapshot.phase = .noEcu
            return
        }

        var supported = supported01_20

        // 6. ATDPN
        let atdpnReply = await sendCommand("ATDPN")
        var isCan = false
        var protocolId = ""
        if case .ok(let linesAtdpn) = atdpnReply, let line = linesAtdpn.first {
            protocolId = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let stripped = protocolId.uppercased().drop(while: { $0 == "A" })
            if let first = stripped.first {
                let charStr = String(first)
                isCan = ["6", "7", "8", "9", "A", "B"].contains(charStr)
            }
        }
        snapshot.protocolId = protocolId
        snapshot.isCan = isCan
        snapshot.hintEnabled = isCan

        // 7. Query ranges 0120, 0140, 0160 if supported
        if SupportedPids.isNextRangeSupported(range: 0x00, pids: supported) {
            let r20 = await sendCommand("0120")
            if case .ok(let l20) = r20 {
                let s20 = SupportedPids.parseReplyLines(l20, range: 0x20)
                supported.formUnion(s20)

                if SupportedPids.isNextRangeSupported(range: 0x20, pids: supported) {
                    let r40 = await sendCommand("0140")
                    if case .ok(let l40) = r40 {
                        let s40 = SupportedPids.parseReplyLines(l40, range: 0x40)
                        supported.formUnion(s40)

                        if SupportedPids.isNextRangeSupported(range: 0x40, pids: supported) {
                            let r60 = await sendCommand("0160")
                            if case .ok(let l60) = r60 {
                                let s60 = SupportedPids.parseReplyLines(l60, range: 0x60)
                                supported.formUnion(s60)
                            }
                        }
                    }
                }
            }
        }
        snapshot.supportedPids = supported

        // 8. 0902 (VIN)
        let vinReply = await sendCommand("0902")
        if case .ok(let vinLines) = vinReply {
            snapshot.vin = Vin.decode(lines: vinLines, isCan: isCan)
        } else {
            snapshot.vin = nil
        }

        // 9. 0101 (Readiness & MIL)
        let r0101 = await sendCommand("0101")
        if case .ok(let l0101) = r0101, let firstLine = l0101.first {
            snapshot.readiness = Readiness.decode(reply: firstLine)
        }

        // 10. 03 (Stored DTCs)
        let r03 = await sendCommand("03")
        if case .ok(let l03) = r03 {
            snapshot.storedDtcs = Dtc.decode(lines: l03, isCan: isCan)
        }

        // 11. 07 (Pending DTCs)
        let r07 = await sendCommand("07")
        if case .ok(let l07) = r07 {
            snapshot.pendingDtcs = Dtc.decode(lines: l07, isCan: isCan)
        }

        snapshot.phase = .live

        // Initialize scheduler with initial full cycle and evaluate initial alerts
        let scheduler = PollScheduler(supportedPids: supported, isCan: isCan, hintEnabled: isCan, initialFullCycle: true)
        self.pollScheduler = scheduler
        evaluateAlerts()
    }

    /// Runs a single poll cycle across scheduled PIDs.
    public func stepPollCycle() async {
        guard snapshot.phase == .live, var scheduler = pollScheduler else {
            return
        }

        let batch = scheduler.nextBatch(elapsedMs: elapsedMs)
        for command in batch {
            var actualCmd = command
            if !snapshot.hintEnabled && actualCmd.count == 5 && actualCmd.hasSuffix("1") {
                actualCmd = String(actualCmd.dropLast())
            }

            var reply = await sendCommand(actualCmd)

            // Quirks: if response count hint was rejected with "?", disable hint and retry PID without it
            if case .unknown = reply, snapshot.isCan, snapshot.hintEnabled, actualCmd.count == 5, actualCmd.hasSuffix("1") {
                snapshot.hintEnabled = false
                scheduler.enableHint(false)
                let retryCmd = String(actualCmd.dropLast())
                reply = await sendCommand(retryCmd)
                handleCommandReply(command: retryCmd, reply: reply)
                scheduler.recordResult(command: retryCmd, reply: reply)
                continue
            }

            // Quirks: if reply was STOPPED, retry once after 100ms
            if case .error(let kind) = reply, kind == .stopped {
                try? await clock.sleep(for: .milliseconds(100))
                reply = await sendCommand(actualCmd)
            }

            handleCommandReply(command: actualCmd, reply: reply)
            scheduler.recordResult(command: actualCmd, reply: reply)
        }

        self.pollScheduler = scheduler
        elapsedMs += 2000
        evaluateAlerts()
    }

    /// Runs N complete poll cycles.
    public func runCycles(count: Int) async {
        await start()
        for _ in 0..<count {
            await stepPollCycle()
        }
    }

    private func handleCommandReply(command: String, reply: ElmReply) {
        guard case .ok(let lines) = reply else { return }

        // Strip trailing hint character '1' for PID lookup
        var baseCmd = command.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if snapshot.isCan && baseCmd.hasPrefix("01") && baseCmd.count == 5 && baseCmd.hasSuffix("1") {
            baseCmd = String(baseCmd.dropLast())
        }

        if baseCmd == "0101", let first = lines.first {
            snapshot.readiness = Readiness.decode(reply: first)
        } else if baseCmd == "03" {
            snapshot.storedDtcs = Dtc.decode(lines: lines, isCan: snapshot.isCan)
        } else if baseCmd == "07" {
            snapshot.pendingDtcs = Dtc.decode(lines: lines, isCan: snapshot.isCan)
        } else if let param = PidCatalog.paramName(forCommand: baseCmd) {
            if let val = PidCatalog.decode(command: baseCmd, lines: lines) {
                snapshot.readings[param] = val
            }
        }
    }

    private func evaluateAlerts() {
        let input = AlertInput(
            timestampMs: elapsedMs,
            rpm: snapshot.readings["RPM"],
            speed: snapshot.readings["SPEED"],
            coolant: snapshot.readings["COOLANT_TEMP"],
            voltage: snapshot.readings["CONTROL_MODULE_VOLTAGE"] ?? snapshot.readings["ADAPTER_VOLTAGE"],
            fuel: snapshot.readings["FUEL_LEVEL"],
            stft: snapshot.readings["SHORT_FUEL_TRIM_B1"],
            ltft: snapshot.readings["LONG_FUEL_TRIM_B1"],
            dtcsStored: snapshot.storedDtcs,
            dtcsPending: snapshot.pendingDtcs
        )

        let result = alertEngine.evaluate(input: input)
        snapshot.activeAlerts = result.active
        snapshot.timestampMs = elapsedMs
    }
}
