import Testing
import Foundation
@testable import AutopalCore

@Suite("Alert evaluation against alert_scenarios.csv")
struct AlertScenariosTests {
    struct ScenarioRow: Sendable, CustomTestStringConvertible {
        let scenario: String
        let profile: String
        let tMs: Int64
        let rpm: Double?
        let speed: Double?
        let coolant: Double?
        let voltage: Double?
        let fuel: Double?
        let stft: Double?
        let ltft: Double?
        let dtcsStored: [String]
        let dtcsPending: [String]
        let expectRaised: Set<AlertId>
        let expectActive: Set<AlertId>

        var testDescription: String {
            "[\(scenario)] t=\(tMs) rpm=\(String(describing: rpm)) coolant=\(String(describing: coolant)) v=\(String(describing: voltage)) -> raised: \(expectRaised) active: \(expectActive)"
        }
    }

    static var scenarioGroups: [String: [ScenarioRow]] {
        let rows = CsvHelper.loadRows(named: "alert_scenarios")
        var groups: [String: [ScenarioRow]] = [:]

        for row in rows {
            let sc = row["scenario"] ?? ""
            let tMs = Int64(row["t_ms"] ?? "0") ?? 0
            let rpm = Double(row["rpm"] ?? "")
            let speed = Double(row["speed"] ?? "")
            let coolant = Double(row["coolant"] ?? "")
            let voltage = Double(row["voltage"] ?? "")
            let fuel = Double(row["fuel"] ?? "")
            let stft = Double(row["stft"] ?? "")
            let ltft = Double(row["ltft"] ?? "")

            let storedStr = row["dtcs_stored"] ?? ""
            let dtcsStored: [String] = (storedStr == "-" || storedStr.isEmpty) ? [] : storedStr.components(separatedBy: "|")

            let pendingStr = row["dtcs_pending"] ?? ""
            let dtcsPending: [String] = (pendingStr == "-" || pendingStr.isEmpty) ? [] : pendingStr.components(separatedBy: "|")

            let raisedStr = row["expect_raised"] ?? ""
            let expectRaised: Set<AlertId> = (raisedStr == "-" || raisedStr.isEmpty) ? [] : Set(raisedStr.components(separatedBy: "|").compactMap { AlertId(rawValue: $0) })

            let activeStr = row["expect_active"] ?? ""
            let expectActive: Set<AlertId> = (activeStr == "-" || activeStr.isEmpty) ? [] : Set(activeStr.components(separatedBy: "|").compactMap { AlertId(rawValue: $0) })

            let item = ScenarioRow(
                scenario: sc,
                profile: row["profile"] ?? "petrol6500",
                tMs: tMs,
                rpm: rpm,
                speed: speed,
                coolant: coolant,
                voltage: voltage,
                fuel: fuel,
                stft: stft,
                ltft: ltft,
                dtcsStored: dtcsStored,
                dtcsPending: dtcsPending,
                expectRaised: expectRaised,
                expectActive: expectActive
            )
            groups[sc, default: []].append(item)
        }
        return groups
    }

    @Test("Run each scenario chronologically", arguments: Array(scenarioGroups.keys))
    func testScenario(scenarioName: String) {
        guard let steps = Self.scenarioGroups[scenarioName] else { return }
        let profileName = steps.first?.profile ?? "petrol6500"
        let profile = profileName == "diesel4500" ? VehicleProfile.diesel4500 : VehicleProfile.petrol6500
        var engine = AlertEngine(profile: profile)

        for step in steps {
            let input = AlertInput(
                timestampMs: step.tMs,
                rpm: step.rpm,
                speed: step.speed,
                coolant: step.coolant,
                voltage: step.voltage,
                fuel: step.fuel,
                stft: step.stft,
                ltft: step.ltft,
                dtcsStored: step.dtcsStored,
                dtcsPending: step.dtcsPending
            )

            let result = engine.evaluate(input: input)
            #expect(result.raised == step.expectRaised, "Scenario '\(scenarioName)' at t=\(step.tMs) raised mismatch: got \(result.raised), expected \(step.expectRaised)")
            #expect(result.active == step.expectActive, "Scenario '\(scenarioName)' at t=\(step.tMs) active mismatch: got \(result.active), expected \(step.expectActive)")
        }
    }
}
