import Foundation

/// Fast and safe hexadecimal encoding and decoding utilities.
public enum Hex: Sendable {
    private static let hexDigits: [UInt8] = Array("0123456789ABCDEF".utf8)

    /// Encodes a sequence of bytes into an uppercase hexadecimal string.
    public static func encode<T: Sequence>(_ bytes: T, separator: String = "") -> String where T.Element == UInt8 {
        var result = ""
        var isFirst = true
        for byte in bytes {
            if !isFirst && !separator.isEmpty {
                result.append(separator)
            }
            let high = Int(byte >> 4)
            let low = Int(byte & 0x0F)
            result.append(Character(UnicodeScalar(hexDigits[high])))
            result.append(Character(UnicodeScalar(hexDigits[low])))
            isFirst = false
        }
        return result
    }

    /// Decodes a hexadecimal string (with optional whitespace or colons) into bytes.
    /// Returns `nil` if the string contains non-hex characters or has an odd number of hex digits.
    public static func decode(_ string: String) -> [UInt8]? {
        let trimmed = string.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) && $0 != ":" }
        if trimmed.isEmpty {
            return []
        }
        if trimmed.count % 2 != 0 {
            return nil
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(trimmed.count / 2)

        var iterator = trimmed.makeIterator()
        while let highChar = iterator.next(), let lowChar = iterator.next() {
            guard let highVal = hexNibble(highChar),
                  let lowVal = hexNibble(lowChar) else {
                return nil
            }
            bytes.append((highVal << 4) | lowVal)
        }
        return bytes
    }

    /// Parses an 8-bit unsigned integer from a hex substring.
    public static func parseUInt8(_ string: String) -> UInt8? {
        guard let bytes = decode(string), bytes.count == 1 else { return nil }
        return bytes[0]
    }

    /// Parses a 16-bit unsigned integer from a hex substring (big-endian).
    public static func parseUInt16(_ string: String) -> UInt16? {
        guard let bytes = decode(string), bytes.count == 2 else { return nil }
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }

    /// Parses a 32-bit unsigned integer from a hex substring (big-endian).
    public static func parseUInt32(_ string: String) -> UInt32? {
        guard let bytes = decode(string), bytes.count == 4 else { return nil }
        return (UInt32(bytes[0]) << 24) |
               (UInt32(bytes[1]) << 16) |
               (UInt32(bytes[2]) << 8) |
               UInt32(bytes[3])
    }

    /// Parses a 64-bit unsigned integer from a hex substring (big-endian).
    public static func parseUInt64(_ string: String) -> UInt64? {
        guard let bytes = decode(string), bytes.count == 8 else { return nil }
        var result: UInt64 = 0
        for b in bytes {
            result = (result << 8) | UInt64(b)
        }
        return result
    }

    private static func hexNibble(_ scalar: UnicodeScalar) -> UInt8? {
        let val = scalar.value
        switch val {
        case 0x30...0x39: // '0'...'9'
            return UInt8(val - 0x30)
        case 0x41...0x46: // 'A'...'F'
            return UInt8(val - 0x41 + 10)
        case 0x61...0x66: // 'a'...'f'
            return UInt8(val - 0x61 + 10)
        default:
            return nil
        }
    }
}
