import Testing
import Foundation
@testable import AutopalCore

@Suite("Replay all 6 ELM327 session fixtures", .serialized)
struct AllFixturesTests {
    static func loadFixture(named name: String) -> String {
        if let url = Bundle.module.url(forResource: name, withExtension: "elm", subdirectory: "Resources/elm-sessions") ??
                     Bundle.module.url(forResource: name, withExtension: "elm", subdirectory: "elm-sessions") ??
                     Bundle.module.url(forResource: name, withExtension: "elm") {
            if let str = try? String(contentsOf: url, encoding: .utf8) {
                return str
            }
        }
        let directUrl = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/elm-sessions/\(name).elm")
        if let str = try? String(contentsOf: directUrl, encoding: .utf8) {
            return str
        }

        fatalError("Could not load fixture resource \(name).elm")
    }

    func runFixture(named fixtureName: String) async {
        let content = Self.loadFixture(named: fixtureName)
        let script = FixtureTransport.parse(content: content)

        let clock = TestClock(autoAdvanceThreshold: .milliseconds(300))
        let transport = FixtureTransport(script: script, clock: clock)
        let client = ObdClient(transport: transport, clock: clock)

        if script.cycles == 0 {
            await client.start()
        } else {
            await client.runCycles(count: script.cycles)
        }

        let snapshot = await client.currentSnapshot
        let logExport = await client.trafficLogExport()

        #expect(transport.initMismatches.isEmpty, "Init mismatches in \(fixtureName): \(transport.initMismatches)")
        #expect(transport.unscriptedCommands.isEmpty, "Unscripted commands in \(fixtureName): \(transport.unscriptedCommands)")

        for (key, expectedVal) in script.expectations {
            assertExpectation(
                key: key,
                expectedVal: expectedVal,
                snapshot: snapshot,
                transport: transport,
                logExport: logExport,
                fixtureName: fixtureName
            )
        }
    }

    @Test("Fixture: can_clone_v15_normal")
    func testNormal() async {
        await runFixture(named: "can_clone_v15_normal")
    }

    @Test("Fixture: can_ble_fragmented")
    func testFragmented() async {
        await runFixture(named: "can_ble_fragmented")
    }

    @Test("Fixture: ignition_off")
    func testIgnitionOff() async {
        await runFixture(named: "ignition_off")
    }

    @Test("Fixture: can_faults_multiframe")
    func testMultiframe() async {
        await runFixture(named: "can_faults_multiframe")
    }

    @Test("Fixture: kline_iso9141")
    func testKline() async {
        await runFixture(named: "kline_iso9141")
    }

    @Test("Fixture: clone_quirks")
    func testCloneQuirks() async {
        await runFixture(named: "clone_quirks")
    }

    private func assertExpectation(
        key: String,
        expectedVal: String,
        snapshot: VehicleSnapshot,
        transport: FixtureTransport,
        logExport: String,
        fixtureName: String
    ) {
        switch key {
        case "phase":
            #expect(snapshot.phase.rawValue == expectedVal, "[\(fixtureName)] Phase mismatch: got \(snapshot.phase.rawValue), expected \(expectedVal)")

        case "adapterVersion":
            #expect(snapshot.adapterVersion == expectedVal, "[\(fixtureName)] Adapter version mismatch: got \(snapshot.adapterVersion ?? "nil"), expected \(expectedVal)")

        case "protocol":
            #expect(snapshot.protocolId == expectedVal, "[\(fixtureName)] Protocol mismatch: got \(snapshot.protocolId ?? "nil"), expected \(expectedVal)")

        case "isCan":
            let exp = (expectedVal == "true")
            #expect(snapshot.isCan == exp, "[\(fixtureName)] isCan mismatch: got \(snapshot.isCan), expected \(exp)")

        case "hintEnabled":
            let exp = (expectedVal == "true")
            #expect(snapshot.hintEnabled == exp, "[\(fixtureName)] hintEnabled mismatch: got \(snapshot.hintEnabled), expected \(exp)")

        case "vin":
            let expVin = (expectedVal == "null") ? nil : expectedVal
            #expect(snapshot.vin == expVin, "[\(fixtureName)] VIN mismatch: got \(snapshot.vin ?? "nil"), expected \(expVin ?? "nil")")

        case "supported":
            let expectedPids = Set(expectedVal.split(separator: ",").compactMap { UInt8($0, radix: 16) })
            #expect(expectedPids.isSubset(of: snapshot.supportedPids), "[\(fixtureName)] Supported PIDs mismatch: expected subset \(expectedPids), got \(snapshot.supportedPids)")

        case "neverSent":
            let forbidden = expectedVal.split(separator: ",").map { String($0) }
            for cmd in forbidden {
                let sentMatch = transport.sentCommands.contains { $0 == cmd || $0 == (cmd + "1") }
                #expect(!sentMatch, "[\(fixtureName)] Forbidden command \(cmd) was sent")
            }

        case "reading":
            // Format: PARAM VALUE TOLERANCE
            let parts = expectedVal.split(separator: " ").map { String($0) }
            guard parts.count >= 2 else { return }
            let param = parts[0]
            let expVal = Double(parts[1]) ?? 0.0
            let tol = (parts.count >= 3) ? (Double(parts[2]) ?? 0.0) : 0.0

            let actual = snapshot.readings[param]
            #expect(actual != nil, "[\(fixtureName)] Expected reading for \(param) but found nil")
            if let actual {
                let diff = abs(actual - expVal)
                #expect(diff <= tol + 0.0001, "[\(fixtureName)] Reading \(param): got \(actual), expected \(expVal) ± \(tol)")
            }

        case "milOn":
            let exp = (expectedVal == "true")
            #expect(snapshot.readiness?.milOn == exp, "[\(fixtureName)] MIL mismatch: got \(snapshot.readiness?.milOn ?? false), expected \(exp)")

        case "storedDtcs":
            let expectedList = (expectedVal == "-") ? [] : expectedVal.split(separator: ",").map { String($0) }
            #expect(Set(snapshot.storedDtcs) == Set(expectedList), "[\(fixtureName)] Stored DTCs mismatch: got \(snapshot.storedDtcs), expected \(expectedList)")

        case "pendingDtcs":
            let expectedList = (expectedVal == "-") ? [] : expectedVal.split(separator: ",").map { String($0) }
            #expect(Set(snapshot.pendingDtcs) == Set(expectedList), "[\(fixtureName)] Pending DTCs mismatch: got \(snapshot.pendingDtcs), expected \(expectedList)")

        case "incomplete":
            let expectedList = (expectedVal == "-") ? [] : expectedVal.split(separator: ",").map { String($0) }
            let actualIncomplete = snapshot.readiness?.incomplete.map { $0.rawValue } ?? []
            #expect(Set(actualIncomplete) == Set(expectedList), "[\(fixtureName)] Incomplete monitors mismatch: got \(actualIncomplete), expected \(expectedList)")

        case "alertActive":
            let alertId = AlertId(rawValue: expectedVal)
            #expect(alertId != nil && snapshot.activeAlerts.contains(alertId!), "[\(fixtureName)] Expected alert \(expectedVal) to be active. Active alerts: \(snapshot.activeAlerts)")

        case "trafficContains":
            #expect(logExport.contains(expectedVal), "[\(fixtureName)] Expected traffic log to contain '\(expectedVal)'")

        default:
            break
        }
    }
}
