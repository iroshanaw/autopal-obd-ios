import Testing
import Foundation
@testable import AutopalCore

@Suite("VIN decoding against vin_vectors.csv")
struct VinTests {
    struct VinRow: Sendable, CustomTestStringConvertible {
        let isCan: Bool
        let replyLines: [String]
        let expectedVin: String?
        let note: String

        var testDescription: String {
            "isCan=\(isCan) lines=\(replyLines.joined(separator: "|")) -> \(expectedVin ?? "nil")"
        }
    }

    static var testRows: [VinRow] {
        let rows = CsvHelper.loadRows(named: "vin_vectors")
        return rows.map { row in
            let isCan = Bool(row["is_can"] ?? "true") ?? true
            let lines = (row["reply_lines"] ?? "").components(separatedBy: "|")
            let expectedVin = (row["expected_vin"]?.isEmpty ?? true) ? nil : row["expected_vin"]
            return VinRow(
                isCan: isCan,
                replyLines: lines,
                expectedVin: expectedVin,
                note: row["note"] ?? ""
            )
        }
    }

    @Test("Decode VIN vectors", arguments: testRows)
    func testDecodeRow(row: VinRow) {
        let decoded = Vin.decode(lines: row.replyLines, isCan: row.isCan)
        #expect(decoded == row.expectedVin, "Mismatch for \(row.testDescription): got \(decoded ?? "nil"), expected \(row.expectedVin ?? "nil") (\(row.note))")
    }
}
