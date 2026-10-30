import Testing
import Foundation
@testable import AutopalCore

@Suite("Mode 01 PID decoding against pid_vectors.csv")
struct PidDecodeTests {
    struct PidRow: Sendable, CustomTestStringConvertible {
        let command: String
        let replyLines: [String]
        let param: String
        let expected: Double?
        let tolerance: Double
        let note: String

        var testDescription: String {
            "\(command) -> \(param): \(replyLines.joined(separator: "|"))"
        }
    }

    static var testRows: [PidRow] {
        let rows = CsvHelper.loadRows(named: "pid_vectors")
        return rows.map { row in
            let lines = (row["reply_lines"] ?? "").components(separatedBy: "|")
            let expectedVal = Double(row["expected"] ?? "")
            let tolVal = Double(row["tolerance"] ?? "") ?? 0.0
            return PidRow(
                command: row["command"] ?? "",
                replyLines: lines,
                param: row["param"] ?? "",
                expected: expectedVal,
                tolerance: tolVal,
                note: row["note"] ?? ""
            )
        }
    }

    @Test("Decode PID vectors", arguments: testRows)
    func testDecodeRow(row: PidRow) {
        let decoded = PidCatalog.decode(command: row.command, lines: row.replyLines)

        if let expected = row.expected {
            guard let val = decoded else {
                Issue.record("Expected \(expected) for \(row.param), got nil (\(row.note))")
                return
            }
            let diff = abs(val - expected)
            #expect(diff <= row.tolerance + 0.0001, "Expected \(expected) ± \(row.tolerance), got \(val) (\(row.note))")
        } else {
            #expect(decoded == nil, "Expected nil for \(row.param), got \(String(describing: decoded)) (\(row.note))")
        }
    }
}
