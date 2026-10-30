import Testing
import Foundation
@testable import AutopalCore

@Suite("ElmSession framing and timeouts", .serialized)
struct ElmSessionTests {
    @Test("Fragments accumulated until '>' prompt; NUL bytes ignored")
    func testFragmentationAndNulHandling() async throws {
        let clock = TestClock()
        let transport = MockTransport()
        let session = ElmSession(transport: transport, clock: clock)

        // Start session send in background task
        async let sendTask = session.send("ATZ")

        // Feed fragments: NUL bytes, partial text, trailing prompt
        try await Task.sleep(nanoseconds: 10_000_000)
        transport.yieldIncoming(Data([0x00, 0x41, 0x54])) // NUL, 'A', 'T'
        transport.yieldIncoming(Data([0x5A, 0x0D, 0x00, 0x0D])) // 'Z', \r, NUL, \r
        transport.yieldIncoming(Data([0x45, 0x4C, 0x4D, 0x33, 0x32, 0x37])) // "ELM327"
        transport.yieldIncoming(Data([0x0D, 0x3E])) // \r, '>'

        let reply = try await sendTask
        #expect(reply == .ok(["ELM327"]))
    }

    @Test("Prompt mid-chunk terminates command and leaves remainder")
    func testPromptMidChunk() async throws {
        let clock = TestClock()
        let transport = MockTransport()
        let session = ElmSession(transport: transport, clock: clock)

        async let sendTask1 = session.send("ATE0")
        try await Task.sleep(nanoseconds: 10_000_000)
        transport.yieldIncoming(Data("OK\r>41".utf8))

        let reply1 = try await sendTask1
        #expect(reply1 == .ok(["OK"]))

        // Remainder "41" followed by "0C1AF8\r>"
        async let sendTask2 = session.send("010C")
        try await Task.sleep(nanoseconds: 10_000_000)
        transport.yieldIncoming(Data("0C1AF8\r>".utf8))

        let reply2 = try await sendTask2
        #expect(reply2 == .ok(["410C1AF8"]))
    }

    @Test("Timeout after deadline, 300 ms drain discards late bytes")
    func testTimeoutAndDrain() async throws {
        let clock = TestClock(autoAdvanceThreshold: .milliseconds(400))
        let transport = MockTransport()
        let session = ElmSession(transport: transport, clock: clock)

        let task = Task {
            try await session.send("0105")
        }

        // Wait for timeout sleep to register
        var waited = 0
        while clock.sleeperCount == 0 && waited < 2000 {
            try await Task.sleep(nanoseconds: 1_000_000)
            waited += 1
        }

        // Advance past 2.5s default timeout
        clock.advance(by: .milliseconds(2550))

        // Late reply arrives during the drain window
        transport.yieldIncoming(Data("41057B\r>".utf8))

        let reply = try await task.value
        #expect(reply == .timeout)

        // Next command should not see the discarded late reply
        async let nextTask = session.send("010C")
        try await Task.sleep(nanoseconds: 10_000_000)
        transport.yieldIncoming(Data("410C1AF8\r>".utf8))

        let nextReply = try await nextTask
        #expect(nextReply == .ok(["410C1AF8"]))
    }

    @Test("Timeouts per command: 5s for ATZ, 15s for first OBD after ATSP0")
    func testCommandSpecificTimeouts() async {
        let clock = TestClock()
        let transport = MockTransport()
        let session = ElmSession(transport: transport, clock: clock)

        let tAtz = await session.timeoutFor(command: "ATZ")
        #expect(tAtz == .seconds(5))

        let tStandard = await session.timeoutFor(command: "010C")
        #expect(tStandard == .milliseconds(2500))

        // ATSP0 changes the timeout of the following OBD command to 15s
        await session.recordSentCommand("ATSP0")
        let tObdAfterAtsp0 = await session.timeoutFor(command: "0100")
        #expect(tObdAfterAtsp0 == .seconds(15))

        // Once the OBD command has been tracked, timeout returns to default 2.5s
        await session.recordSentCommand("0100")
        let tNext = await session.timeoutFor(command: "010C")
        #expect(tNext == .milliseconds(2500))
    }
}
