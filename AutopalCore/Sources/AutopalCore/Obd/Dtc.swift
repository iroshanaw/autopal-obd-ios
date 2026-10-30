import Foundation

/// Decodes OBD-II Diagnostic Trouble Codes (Mode 03 stored, Mode 07 pending).
public enum Dtc: Sendable {
    /// Decodes a 2-byte hex string (4 characters) into a 5-character SAE DTC string (e.g. "P0133").
    /// Returns nil if the hex represents padding ("0000") or is invalid.
    public static func decodeSingleCode(hex: String) -> String? {
        guard let bytes = Hex.decode(hex), bytes.count == 2 else {
            return nil
        }
        return decodeBytes(bytes[0], bytes[1])
    }

    /// Decodes two bytes into a 5-character SAE DTC string.
    public static func decodeBytes(_ b1: UInt8, _ b2: UInt8) -> String? {
        if b1 == 0 && b2 == 0 {
            return nil // Padding
        }

        let prefixChar: Character
        switch (b1 >> 6) & 0x03 {
        case 0: prefixChar = "P"
        case 1: prefixChar = "C"
        case 2: prefixChar = "B"
        case 3: prefixChar = "U"
        default: return nil
        }

        let firstDigit = (b1 >> 4) & 0x03
        let secondDigit = b1 & 0x0F
        let thirdByte = b2

        let hexSecond = String(format: "%X", secondDigit)
        let hexThird = String(format: "%02X", thirdByte)

        return "\(prefixChar)\(firstDigit)\(hexSecond)\(hexThird)"
    }

    /// Decodes Mode 03 / Mode 07 lines into an array of unique DTCs.
    public static func decode(lines: [String], isCan: Bool) -> [String] {
        var resultCodes: [String] = []

        // If lines contain "NO DATA", return empty
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if trimmed == "NO DATA" {
                return []
            }
        }

        if isCan {
            resultCodes = decodeCan(lines: lines)
        } else {
            resultCodes = decodeNonCan(lines: lines)
        }

        // Return de-duplicated while preserving encounter order
        var seen = Set<String>()
        var unique: [String] = []
        for code in resultCodes {
            if !seen.contains(code) {
                seen.insert(code)
                unique.append(code)
            }
        }
        return unique
    }

    private static func decodeCan(lines: [String]) -> [String] {
        // Check if this is an ISO-TP multi-frame session with "0:", "1:", etc.
        let isMultiFrame = lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("0:") || trimmed.hasPrefix("1:")
        }

        if isMultiFrame {
            return decodeCanMultiFrame(lines: lines)
        } else {
            return decodeCanSingleFrames(lines: lines)
        }
    }

    private static func decodeCanMultiFrame(lines: [String]) -> [String] {
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

        // In CAN multi-frame:
        // byte 0: Mode response (0x43 or 0x47)
        // byte 1: DTC count
        guard payloadBytes.count >= 2 else { return [] }
        let mode = payloadBytes[0]
        guard mode == 0x43 || mode == 0x47 else { return [] }

        let count = Int(payloadBytes[1])
        var codes: [String] = []

        var offset = 2
        var decodedCount = 0
        while offset + 1 < payloadBytes.count && decodedCount < count {
            if let code = decodeBytes(payloadBytes[offset], payloadBytes[offset + 1]) {
                codes.append(code)
            }
            offset += 2
            decodedCount += 1
        }

        return codes
    }

    private static func decodeCanSingleFrames(lines: [String]) -> [String] {
        var codes: [String] = []

        for line in lines {
            guard let bytes = Hex.decode(line), bytes.count >= 2 else {
                continue
            }
            let mode = bytes[0]
            guard mode == 0x43 || mode == 0x47 else {
                continue
            }

            let count = Int(bytes[1])
            if count == 0 {
                continue
            }

            var offset = 2
            var decodedCount = 0
            while offset + 1 < bytes.count && decodedCount < count {
                if let code = decodeBytes(bytes[offset], bytes[offset + 1]) {
                    codes.append(code)
                }
                offset += 2
                decodedCount += 1
            }
        }

        return codes
    }

    private static func decodeNonCan(lines: [String]) -> [String] {
        var codes: [String] = []

        for line in lines {
            guard let bytes = Hex.decode(line), bytes.count >= 1 else {
                continue
            }
            let mode = bytes[0]
            guard mode == 0x43 || mode == 0x47 else {
                continue
            }

            // Non-CAN: no count byte; payload is pairs of bytes until end of line
            var offset = 1
            while offset + 1 < bytes.count {
                if let code = decodeBytes(bytes[offset], bytes[offset + 1]) {
                    codes.append(code)
                }
                offset += 2
            }
        }

        return codes
    }
}
