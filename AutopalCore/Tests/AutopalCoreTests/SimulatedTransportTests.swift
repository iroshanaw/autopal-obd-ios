import Testing
import Foundation
@testable import AutopalCore

@Suite("SimulatedElm327Transport scenarios", .serialized)
struct SimulatedTransportTests {

    final class LinkRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _states: [LinkState] = []
        func append(_ state: LinkState) {
            lock.withLock { _states.append(state) }
        }
        var containsDisconnected: Bool {
            lock.withLock { _states.contains(.disconnected) }
        }
    }

    @Test("Scenario: normal reaches LIVE with realistic data and no alerts")
    func testNormal() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .normal, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        await client.runCycles(count: 2)

        let snapshot = await client.currentSnapshot
        #expect(snapshot.phase == .live)
        #expect(snapshot.protocolId == "A6")
        #expect(snapshot.isCan == true)
        #expect(snapshot.vin == "1HGCM82633A004352")

        #expect(snapshot.readings["RPM"] ?? 0 > 700)
        #expect(snapshot.readings["SPEED"] ?? 0 >= 0)
        #expect(snapshot.readings["COOLANT_TEMP"] == 90.0)
        #expect(snapshot.readings["CONTROL_MODULE_VOLTAGE"] == 14.1)
        #expect(snapshot.storedDtcs.isEmpty)
        #expect(snapshot.activeAlerts.isEmpty)
    }

    @Test("Scenario: ignitionOff reaches NO_ECU with voltage available")
    func testIgnitionOff() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .ignitionOff, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        await client.start()

        let snapshot = await client.currentSnapshot
        #expect(snapshot.phase == .noEcu)
        #expect(snapshot.adapterVersion == "ELM327 v1.5")
        #expect(snapshot.readings["ADAPTER_VOLTAGE"] == 12.4)
        #expect(snapshot.readings["RPM"] == nil)
    }

    @Test("Scenario: overheat triggers COOLANT_CRITICAL alert")
    func testOverheat() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .overheat, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        // 4 cycles = 8000 ms elapsed, satisfying 5000 ms sustain for COOLANT_CRITICAL
        await client.runCycles(count: 4)

        let snapshot = await client.currentSnapshot
        #expect(snapshot.phase == .live)
        #expect(snapshot.readings["COOLANT_TEMP"] == 119.0)
        #expect(snapshot.activeAlerts.contains(.coolantCritical), "Expected COOLANT_CRITICAL alert, got: \(snapshot.activeAlerts)")
    }

    @Test("Scenario: chargingFault triggers CHARGING_LOW alert")
    func testChargingFault() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .chargingFault, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        // 12 cycles = 24,000 ms elapsed, satisfying 20,000 ms sustain for CHARGING_LOW
        await client.runCycles(count: 12)

        let snapshot = await client.currentSnapshot
        #expect(snapshot.phase == .live)
        #expect(snapshot.readings["CONTROL_MODULE_VOLTAGE"] == 11.6)
        #expect(snapshot.activeAlerts.contains(.chargingLow), "Expected CHARGING_LOW alert, got: \(snapshot.activeAlerts)")
    }

    @Test("Scenario: vacuumLeak triggers TRIM_TOTAL alert")
    func testVacuumLeak() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .vacuumLeak, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        // 17 cycles = 34,000 ms elapsed, satisfying 30,000 ms sustain for TRIM_TOTAL
        await client.runCycles(count: 17)

        let snapshot = await client.currentSnapshot
        #expect(snapshot.phase == .live)
        #expect(snapshot.readings["SHORT_FUEL_TRIM_B1"] ?? 0 > 17.0)
        #expect(snapshot.readings["LONG_FUEL_TRIM_B1"] ?? 0 > 9.0)
        #expect(snapshot.activeAlerts.contains(.trimTotal), "Expected TRIM_TOTAL alert, got: \(snapshot.activeAlerts)")
    }

    @Test("Scenario: misfire reports P0300 and triggers MISFIRE alert")
    func testMisfire() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .misfire, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        await client.runCycles(count: 2)

        let snapshot = await client.currentSnapshot
        #expect(snapshot.phase == .live)
        #expect(snapshot.storedDtcs.contains("P0300"))
        #expect(snapshot.activeAlerts.contains(.misfire))
        #expect(snapshot.activeAlerts.contains(.newDtcStored))
    }

    @Test("Scenario: dropout drops link after several cycles")
    func testDropout() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .dropout, clock: clock)

        let recorder = LinkRecorder()
        let linkCollector = Task {
            for await state in transport.linkState {
                recorder.append(state)
            }
        }

        let client = ObdClient(transport: transport, clock: clock)
        await client.runCycles(count: 4)

        linkCollector.cancel()
        #expect(recorder.containsDisconnected)
    }

    @Test("Replies never classify as unknown")
    func testNoRepliesClassifyAsUnknown() async throws {
        let transport = SimulatedElm327Transport(scenario: .normal)
        try await transport.connect()

        let testCommands = [
            "ATZ", "ATE0", "ATL0", "ATS0", "ATH0", "ATAT1", "ATSP0", "ATDPN", "ATRV",
            "0100", "0120", "0140", "0160",
            "0902", "0101", "03", "07",
            "010C", "010C1", "010D", "010D1", "0105", "01051", "0111", "01111",
            "0104", "01041", "010F", "010F1", "015C", "015C1", "0142", "01421",
            "0110", "01101", "0106", "01061", "0107", "01071", "012F", "012F1",
            "010A", "010A1", "0146", "01461"
        ]

        var incomingIterator = transport.incoming.makeAsyncIterator()

        for cmd in testCommands {
            try await transport.write(Data((cmd + "\r").utf8))
            guard let replyData = await incomingIterator.next(),
                  let replyStr = String(data: replyData, encoding: .utf8) else {
                Issue.record("No reply received for command: \(cmd)")
                continue
            }

            let classified = ElmReply.classify(raw: replyStr, command: cmd)
            #expect(classified != .unknown, "Command '\(cmd)' returned reply '\(replyStr)' which classified as .unknown")
        }

        await transport.close()
    }

    @Test("Dynamic scenario switching")
    func testDynamicScenarioSwitching() async {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = SimulatedElm327Transport(scenario: .normal, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        await client.runCycles(count: 2)
        var snapshot = await client.currentSnapshot
        #expect(snapshot.activeAlerts.isEmpty)

        // Dynamically switch to overheat
        transport.setScenario(.overheat)
        #expect(transport.scenario == .overheat)

        // 4 cycles = 8000 ms elapsed, satisfying 5000 ms sustain for COOLANT_CRITICAL
        await client.runCycles(count: 4)

        snapshot = await client.currentSnapshot
        #expect(snapshot.activeAlerts.contains(.coolantCritical))
    }
}
