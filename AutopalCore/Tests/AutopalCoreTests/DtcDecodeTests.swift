import Testing
import Foundation
@testable import AutopalCore

@Suite("DTC decoding against dtc_vectors.csv")
struct DtcDecodeTests {
    struct DtcRow: Sendable, CustomTestStringConvertible {
        let group: String
        let isCan: Bool?
        let replyLines: [String]
        let expectedCodes: [String]
        let note: String

        var testDescription: String {
            "[\(group)] isCan=\(String(describing: isCan)) lines=\(replyLines.joined(separator: "|")) -> \(expectedCodes.joined(separator: ","))"
        }
    }

    static var testRows: [DtcRow] {
        let rows = CsvHelper.loadRows(named: "dtc_vectors")
        return rows.map { row in
            let isCanStr = row["is_can"] ?? ""
            let isCan = isCanStr.isEmpty ? nil : Bool(isCanStr)
            let lines = (row["reply_lines"] ?? "").components(separatedBy: "|")
            let expectedStr = row["expected_codes"] ?? ""
            let expectedCodes: [String]
            if expectedStr == "-" || expectedStr.isEmpty {
                expectedCodes = []
            } else {
                expectedCodes = expectedStr.components(separatedBy: "|")
            }
            return DtcRow(
                group: row["group"] ?? "",
                isCan: isCan,
                replyLines: lines,
                expectedCodes: expectedCodes,
                note: row["note"] ?? ""
            )
        }
    }

    @Test("Decode DTC vectors", arguments: testRows)
    func testDecodeRow(row: DtcRow) {
        if row.group == "single_bytes" {
            let hex = row.replyLines[0]
            let code = Dtc.decodeSingleCode(hex: hex)
            if row.expectedCodes.isEmpty {
                #expect(code == nil, "Expected padding (nil) for \(hex)")
            } else {
                #expect(code == row.expectedCodes[0], "Expected \(row.expectedCodes[0]) for \(hex)")
            }
        } else {
            let isCan = row.isCan ?? true
            let codes = Dtc.decode(lines: row.replyLines, isCan: isCan)
            #expect(Set(codes) == Set(row.expectedCodes), "Mismatch for \(row.testDescription): got \(codes), expected \(row.expectedCodes) (\(row.note))")
        }
    }
}
