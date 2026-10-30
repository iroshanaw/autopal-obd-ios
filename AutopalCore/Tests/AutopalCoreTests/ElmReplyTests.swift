import Testing
@testable import AutopalCore

@Suite("ELM327 reply classification")
struct ElmReplyTests {
    @Test("Clean reply with echo stripped")
    func testEchoStripped() {
        let reply = ElmReply.classify(raw: "010C\r41 0C 1A F8", command: "010C")
        #expect(reply == .ok(["41 0C 1A F8"]))
    }

    @Test("SEARCHING and BUS INIT noise stripped")
    func testNoiseStripped() {
        let reply1 = ElmReply.classify(raw: "SEARCHING...\r41 00 BE 3F A8 13", command: "0100")
        #expect(reply1 == .ok(["41 00 BE 3F A8 13"]))

        let reply2 = ElmReply.classify(raw: "BUS INIT: ...OK\r41 00 BE 3F A8 13", command: "0100")
        #expect(reply2 == .ok(["41 00 BE 3F A8 13"]))
    }

    @Test("NO DATA reply")
    func testNoData() {
        let reply = ElmReply.classify(raw: "NO DATA", command: "0902")
        #expect(reply == .noData)
    }

    @Test("UNABLE TO CONNECT reply")
    func testUnableToConnect() {
        let reply = ElmReply.classify(raw: "UNABLE TO CONNECT", command: "0100")
        #expect(reply == .unableToConnect)
    }

    @Test("Unknown question mark reply")
    func testUnknown() {
        let reply = ElmReply.classify(raw: "?", command: "ATL0")
        #expect(reply == .unknown)
    }

    @Test("Error kinds")
    func testErrors() {
        #expect(ElmReply.classify(raw: "CAN ERROR", command: "010C") == .error(.canError))
        #expect(ElmReply.classify(raw: "BUS ERROR", command: "010C") == .error(.busError))
        #expect(ElmReply.classify(raw: "BUS BUSY", command: "010C") == .error(.busBusy))
        #expect(ElmReply.classify(raw: "BUFFER FULL", command: "010C") == .error(.bufferFull))
        #expect(ElmReply.classify(raw: "DATA ERROR", command: "010C") == .error(.dataError))
        #expect(ElmReply.classify(raw: "STOPPED", command: "010D") == .error(.stopped))
        #expect(ElmReply.classify(raw: "LV RESET", command: "010C") == .error(.lvReset))
    }

    @Test("Multi-line and multi-frame replies")
    func testMultiLineOk() {
        let raw = "0: 43 04 01 33 03 00\r1: 04 20 00 00 00 00"
        let reply = ElmReply.classify(raw: raw, command: "03")
        #expect(reply == .ok([
            "0: 43 04 01 33 03 00",
            "1: 04 20 00 00 00 00"
        ]))
    }
}
