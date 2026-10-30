import Foundation

/// Decodes the 17-character Vehicle Identification Number (Mode 09 PID 02).
public enum Vin: Sendable {
    public static func decode(lines: [String], isCan: Bool) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if trimmed == "NO DATA" || trimmed == "?" {
                return nil
            }
        }

        let vinStr: String?
        if isCan {
            vinStr = decodeCan(lines: lines)
        } else {
            vinStr = decodeNonCan(lines: lines)
        }

        guard let vin = vinStr, vin.count == 17 else {
            return nil
        }
        return vin
    }

    private static func decodeCan(lines: [String]) -> String? {
        var payloadBytes: [UInt8] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let colonIndex = trimmed.firstIndex(of: ":") else {
                continue
            }
            let frameContent = String(trimmed[trimmed.index(after: colonIndex)...])
            if let bytes = Hex.decode(frameContent) {
                payloadBytes.append(contentsOf: bytes)
            }
        }

        // Expected header: 49 02 01 (mode 09, PID 02, data item count 01)
        guard payloadBytes.count >= 3 else { return nil }
        guard payloadBytes[0] == 0x49 && payloadBytes[1] == 0x02 else { return nil }

        let vinBytes = Array(payloadBytes.dropFirst(3).prefix(17))
        guard vinBytes.count == 17 else { return nil }

        let ascii = vinBytes.map { Character(UnicodeScalar($0)) }
        return String(ascii)
    }

    private static func decodeNonCan(lines: [String]) -> String? {
        // Collect 5 frames sorted by item number (01 to 05)
        var frames: [(UInt8, [UInt8])] = []

        for line in lines {
            guard let bytes = Hex.decode(line), bytes.count >= 3 else {
                continue
            }
            guard bytes[0] == 0x49 && bytes[1] == 0x02 else {
                continue
            }
            let itemNum = bytes[2]
            let data = Array(bytes.dropFirst(3))
            frames.append((itemNum, data))
        }

        frames.sort { $0.0 < $1.0 }
        guard !frames.isEmpty else { return nil }

        var vinBytes: [UInt8] = []

        // First frame (01): drop leading null bytes (e.g. 00 00 00 31 -> 31)
        if let first = frames.first(where: { $0.0 == 0x01 }) {
            let dropped = first.1.drop(while: { $0 == 0x00 })
            vinBytes.append(contentsOf: dropped)
        }

        // Subsequent frames: append all data bytes
        for frame in frames where frame.0 > 0x01 {
            vinBytes.append(contentsOf: frame.1)
        }

        guard vinBytes.count >= 17 else { return nil }
        let exactVin = Array(vinBytes.prefix(17))
        let ascii = exactVin.map { Character(UnicodeScalar($0)) }
        return String(ascii)
    }
}
