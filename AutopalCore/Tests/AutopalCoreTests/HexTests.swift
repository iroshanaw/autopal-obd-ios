import Testing
import Foundation
@testable import AutopalCore

@Suite("Hex utilities")
struct HexTests {
    @Test("Convert hex strings to bytes")
    func testHexDecode() {
        #expect(Hex.decode("010C") == [0x01, 0x0C])
        #expect(Hex.decode("41 0C 1A F8") == [0x41, 0x0C, 0x1A, 0xF8])
        #expect(Hex.decode("410c1af8") == [0x41, 0x0C, 0x1A, 0xF8])
        #expect(Hex.decode("") == [])
        #expect(Hex.decode("   ") == [])
        #expect(Hex.decode("0") == nil) // odd length
        #expect(Hex.decode("010G") == nil) // non-hex
    }

    @Test("Convert bytes to hex string")
    func testHexEncode() {
        #expect(Hex.encode([0x01, 0x0C]) == "010C")
        #expect(Hex.encode([0x41, 0x0C, 0x1A, 0xF8], separator: " ") == "41 0C 1A F8")
        #expect(Hex.encode([]) == "")
    }

    @Test("Parse integer from hex substring")
    func testParseInt() {
        #expect(Hex.parseUInt8("1A") == 0x1A)
        #expect(Hex.parseUInt16("1AF8") == 0x1AF8)
        #expect(Hex.parseUInt32("0007E500") == 0x0007E500)
        #expect(Hex.parseUInt8("ZZ") == nil)
    }
}
