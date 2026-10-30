import Foundation

enum CsvHelper {
    static func loadRows(named name: String) -> [[String: String]] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "csv") ??
                        Bundle.module.url(forResource: name, withExtension: "csv", subdirectory: "Resources/vectors") ??
                        Bundle.module.url(forResource: name, withExtension: "csv", subdirectory: "vectors") else {
            fatalError("Could not find CSV resource: \(name).csv")
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("Could not read CSV resource at \(url)")
        }

        return parseCsv(content)
    }

    static func parseCsv(_ content: String) -> [[String: String]] {
        let lines = content.components(separatedBy: "\n")
        guard let headerLine = lines.first, !headerLine.trimmingCharacters(in: .whitespaces).isEmpty else {
            return []
        }

        let headers = parseCsvLine(headerLine)
        var rows: [[String: String]] = []

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            let fields = parseCsvLine(trimmed)
            var dict: [String: String] = [:]
            for (idx, header) in headers.enumerated() {
                if idx < fields.count {
                    dict[header] = fields[idx]
                } else {
                    dict[header] = ""
                }
            }
            rows.append(dict)
        }
        return rows
    }

    private static func parseCsvLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        var iterator = line.makeIterator()
        while let ch = iterator.next() {
            if ch == "\"" {
                inQuotes.toggle()
            } else if ch == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(ch)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }
}
