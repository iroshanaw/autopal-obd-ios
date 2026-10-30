import Testing
import Foundation
@testable import AutopalCore

@Suite("Polling tier scheduling and filtering")
struct PollTierTests {
    @Test("Fast tier has fixed order")
    func testFastTierOrder() {
        let fastPids = PollTier.fastPids
        #expect(fastPids == ["010C", "010D", "0111", "0104"])
    }

    @Test("PollScheduler schedules fast tier on every tick")
    func testPollSchedulerFastTier() {
        let supported: Set<UInt8> = [0x0C, 0x0D, 0x11, 0x04] // all fast PIDs supported
        var scheduler = PollScheduler(supportedPids: supported, isCan: false)

        let batch1 = scheduler.nextBatch(elapsedMs: 0)
        #expect(batch1 == ["010C", "010D", "0111", "0104"])

        let batch2 = scheduler.nextBatch(elapsedMs: 200)
        #expect(batch2 == ["010C", "010D", "0111", "0104"])
    }

    @Test("Unsupported PIDs are excluded from all batches")
    func testUnsupportedPidsExcluded() {
        let supported: Set<UInt8> = [0x0C, 0x0D] // Only RPM and Speed supported
        var scheduler = PollScheduler(supportedPids: supported, isCan: false)

        let batch = scheduler.nextBatch(elapsedMs: 0)
        #expect(batch == ["010C", "010D"])
        #expect(!batch.contains("0111"))
        #expect(!batch.contains("0104"))
    }

    @Test("Medium tier runs every 2000 ms")
    func testMediumTierInterval() {
        // Support RPM and Coolant (0x05)
        let supported: Set<UInt8> = [0x0C, 0x05]
        var scheduler = PollScheduler(supportedPids: supported, isCan: false)

        // At t=0, only fast (010C) runs
        let batch0 = scheduler.nextBatch(elapsedMs: 0)
        #expect(batch0 == ["010C"])

        // At t=1000 ms, only fast runs
        let batch1000 = scheduler.nextBatch(elapsedMs: 1000)
        #expect(batch1000 == ["010C"])

        // At t=2000 ms, medium runs
        let batch2000 = scheduler.nextBatch(elapsedMs: 2000)
        #expect(batch2000.contains("010C"))
        #expect(batch2000.contains("0105"))
    }

    @Test("Slow tier runs every 30000 ms and uses ATRV fallback if 0142 unsupported")
    func testSlowTierIntervalAndAtrvFallback() {
        let supportedWithout42: Set<UInt8> = [0x0C, 0x2F] // RPM and Fuel Level (0x2F), no 0x42
        var scheduler = PollScheduler(supportedPids: supportedWithout42, isCan: false)

        let batch0 = scheduler.nextBatch(elapsedMs: 0)
        #expect(!batch0.contains("012F"))
        #expect(!batch0.contains("ATRV"))

        let batch10k = scheduler.nextBatch(elapsedMs: 10000)
        #expect(!batch10k.contains("012F"))
        #expect(!batch10k.contains("ATRV"))

        let batch30k = scheduler.nextBatch(elapsedMs: 30000)
        #expect(batch30k.contains("012F"))
        #expect(batch30k.contains("ATRV"))
    }

    @Test("CAN response hint appended to Mode 01 data PIDs when enabled")
    func testResponseCountHint() {
        let supported: Set<UInt8> = [0x0C, 0x0D]
        var scheduler = PollScheduler(supportedPids: supported, isCan: true, hintEnabled: true)

        let batch = scheduler.nextBatch(elapsedMs: 0)
        #expect(batch.contains("010C1"))
        #expect(batch.contains("010D1"))

        // When hint disabled, original command returned
        scheduler.enableHint(false)
        let batchNoHint = scheduler.nextBatch(elapsedMs: 0)
        #expect(batchNoHint.contains("010C"))
        #expect(!batchNoHint.contains("010C1"))
    }

    @Test("PID dropped after 3 consecutive NO DATA replies")
    func testDropPidAfterThreeNoData() {
        let supported: Set<UInt8> = [0x0C, 0x05]
        var scheduler = PollScheduler(supportedPids: supported, isCan: false)

        scheduler.recordResult(command: "0105", reply: .noData)
        scheduler.recordResult(command: "0105", reply: .noData)
        scheduler.recordResult(command: "0105", reply: .noData)

        #expect(scheduler.isDropped("0105") == true)

        let batch = scheduler.nextBatch(elapsedMs: 2000)
        #expect(!batch.contains("0105"))
    }
}
