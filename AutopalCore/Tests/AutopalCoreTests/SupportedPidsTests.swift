import Testing
@testable import AutopalCore

@Suite("Supported PIDs bitmap decoding")
struct SupportedPidsTests {
    @Test("Decodes 0100 bitmap BE3FA813 to exact PID set")
    func testDecode0100Bitmap() {
        let bitmap = SupportedPids.decode(range: 0x00, hex: "BE3FA813")
        #expect(bitmap.contains(0x01)) // 1st bit (MSB)
        #expect(!bitmap.contains(0x02))
        #expect(bitmap.contains(0x03))
        #expect(bitmap.contains(0x04))
        #expect(bitmap.contains(0x05))
        #expect(bitmap.contains(0x06))
        #expect(bitmap.contains(0x07))
        #expect(!bitmap.contains(0x08))
        #expect(!bitmap.contains(0x09))
        #expect(!bitmap.contains(0x0A))
        #expect(bitmap.contains(0x0B))
        #expect(bitmap.contains(0x0C))
        #expect(bitmap.contains(0x0D))
        #expect(bitmap.contains(0x0E))
        #expect(bitmap.contains(0x0F))
        #expect(bitmap.contains(0x10))
        #expect(bitmap.contains(0x11))
        #expect(!bitmap.contains(0x12))
        #expect(bitmap.contains(0x13))
        #expect(!bitmap.contains(0x14))
        #expect(bitmap.contains(0x15))
        #expect(bitmap.contains(0x1C))
        #expect(bitmap.contains(0x1F))
        #expect(bitmap.contains(0x20)) // bit 0: indicates 0120 is supported

        #expect(bitmap.count == 18)
    }

    @Test("Multi-ECU replies merged via bitwise OR")
    func testMultiEcuMerge() {
        let ecu1 = "410080000000" // PID 01
        let ecu2 = "410040000000" // PID 02
        let merged = SupportedPids.parseReplyLines([ecu1, ecu2], range: 0x00)
        #expect(merged.contains(0x01))
        #expect(merged.contains(0x02))
        #expect(merged.count == 2)
    }

    @Test("Checks if next range is supported")
    func testNextRange() {
        #expect(SupportedPids.isNextRangeSupported(range: 0x00, pids: [0x20]) == true)
        #expect(SupportedPids.isNextRangeSupported(range: 0x00, pids: [0x0C]) == false)
        #expect(SupportedPids.isNextRangeSupported(range: 0x20, pids: [0x40]) == true)
        #expect(SupportedPids.isNextRangeSupported(range: 0x60, pids: [0x80]) == true)
    }
}
