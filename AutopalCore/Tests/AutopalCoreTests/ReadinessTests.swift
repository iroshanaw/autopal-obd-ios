import Testing
import Foundation
@testable import AutopalCore

@Suite("Readiness monitor decoding against readiness_vectors.csv")
struct ReadinessTests {
    struct ReadinessRow: Sendable, CustomTestStringConvertible {
        let reply: String
        let milOn: Bool
        let dtcCount: Int
        let engine: EngineType
        let available: [MonitorType]
        let incomplete: [MonitorType]
        let note: String

        var testDescription: String {
            "\(reply) -> mil=\(milOn) dtcCount=\(dtcCount) engine=\(engine)"
        }
    }

    static var testRows: [ReadinessRow] {
        let rows = CsvHelper.loadRows(named: "readiness_vectors")
        return rows.map { row in
            let reply = row["reply"] ?? ""
            let milOn = Bool(row["mil_on"] ?? "false") ?? false
            let dtcCount = Int(row["dtc_count"] ?? "0") ?? 0
            let engine = (row["engine"] ?? "") == "COMPRESSION" ? EngineType.compression : EngineType.spark

            let availStr = row["available"] ?? ""
            let available: [MonitorType] = availStr.components(separatedBy: "|").compactMap { MonitorType(rawValue: $0) }

            let incompStr = row["incomplete"] ?? ""
            let incomplete: [MonitorType]
            if incompStr == "-" || incompStr.isEmpty {
                incomplete = []
            } else {
                incomplete = incompStr.components(separatedBy: "|").compactMap { MonitorType(rawValue: $0) }
            }

            return ReadinessRow(
                reply: reply,
                milOn: milOn,
                dtcCount: dtcCount,
                engine: engine,
                available: available,
                incomplete: incomplete,
                note: row["note"] ?? ""
            )
        }
    }

    @Test("Decode readiness vectors", arguments: testRows)
    func testDecodeRow(row: ReadinessRow) {
        guard let status = Readiness.decode(reply: row.reply) else {
            Issue.record("Failed to parse readiness for \(row.reply)")
            return
        }

        #expect(status.milOn == row.milOn, "MIL status mismatch for \(row.reply)")
        #expect(status.dtcCount == row.dtcCount, "DTC count mismatch for \(row.reply)")
        #expect(status.engine == row.engine, "Engine type mismatch for \(row.reply)")
        #expect(Set(status.available) == Set(row.available), "Available mismatch for \(row.reply): got \(status.available), expected \(row.available)")
        #expect(Set(status.incomplete) == Set(row.incomplete), "Incomplete mismatch for \(row.reply): got \(status.incomplete), expected \(row.incomplete)")
    }
}
