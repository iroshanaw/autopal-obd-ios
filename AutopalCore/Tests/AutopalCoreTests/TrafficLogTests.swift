import Testing
import Foundation
@testable import AutopalCore

@Suite("Traffic log recording and export")
struct TrafficLogTests {
    @Test("Records TX, RX, and INFO in strict format")
    func testLogFormat() async {
        let clock = TestClock()
        let log = TrafficLog(
            adapter: "ELM327 v1.5",
            transport: "BLE",
            device: "IOS-VLINK",
            appVersion: "0.1.0",
            baseEpochMs: 1729591080000,
            clock: clock
        )

        await log.logTx("ATZ")
        clock.advance(by: .milliseconds(333))
        await log.logRx("ATZ\r\r\rELM327 v1.5")
        clock.advance(by: .milliseconds(500))
        await log.logTimeout(afterMs: 2500, command: "010C")
        clock.advance(by: .milliseconds(200))
        await log.logUnsolicitedDropped("41 0C 1A F8")

        let exported = await log.export(isoDate: "2026-10-27T15:58:00+05:30")
        let lines = exported.components(separatedBy: "\n")

        #expect(lines[0] == "# autopal-traffic-log v1")
        #expect(lines[1] == "# adapter=ELM327 v1.5 transport=BLE device=IOS-VLINK app=0.1.0 exported=2026-10-27T15:58:00+05:30")
        #expect(lines[2] == "1729591080000 TX ATZ")
        #expect(lines[3] == "1729591080333 RX ATZ\\r\\r\\rELM327 v1.5")
        #expect(lines[4] == "1729591080833 INFO TIMEOUT after 2500ms on 010C")
        #expect(lines[5] == "1729591081033 INFO Unsolicited reply dropped: 41 0C 1A F8")
    }
}
