import Foundation

/// Decodes SAE J1979 PID support bitmaps (0100, 0120, 0140, 0160).
public enum SupportedPids: Sendable {
    /// Decodes an 8-character hex string into a set of supported PID numbers for the given range.
    public static func decode(range: UInt8, hex: String) -> Set<UInt8> {
        guard let mask = Hex.parseUInt32(hex) else {
            return []
        }
        return decodeMask(range: range, mask: mask)
    }

    /// Decodes a 32-bit mask into a set of supported PID numbers.
    public static func decodeMask(range: UInt8, mask: UInt32) -> Set<UInt8> {
        var pids = Set<UInt8>()
        for bitIndex in 0..<32 {
            // Bit 31 is range + 1, Bit 0 is range + 32
            let isSet = (mask & (1 << (31 - bitIndex))) != 0
            if isSet {
                let pid = range + UInt8(bitIndex + 1)
                pids.insert(pid)
            }
        }
        return pids
    }

    /// Parses reply lines from one or more ECUs and merges supported PIDs with bitwise OR.
    public static func parseReplyLines(_ lines: [String], range: UInt8) -> Set<UInt8> {
        var mergedMask: UInt32 = 0
        let rangeHex = Hex.encode([range])

        for line in lines {
            let compact = line.unicodeScalars
                .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
                .map { Character($0) }
            let str = String(compact).uppercased()

            guard str.hasPrefix("41" + rangeHex) else {
                continue
            }

            guard let bytes = Hex.decode(str), bytes.count >= 6 else {
                continue
            }

            // bytes[0] = 0x41, bytes[1] = range, bytes[2...5] = 4-byte bitmap
            let maskBytes = Array(bytes[2...5])
            let mask = (UInt32(maskBytes[0]) << 24) |
                       (UInt32(maskBytes[1]) << 16) |
                       (UInt32(maskBytes[2]) << 8) |
                       UInt32(maskBytes[3])
            mergedMask |= mask
        }

        return decodeMask(range: range, mask: mergedMask)
    }

    /// Checks whether the next PID range (e.g. 0120 after 0100) is supported according to the last bit of the current range.
    public static func isNextRangeSupported(range: UInt8, pids: Set<UInt8>) -> Bool {
        pids.contains(range + 0x20)
    }
}
