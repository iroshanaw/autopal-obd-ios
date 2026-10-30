import Foundation
@testable import AutopalCore

/// A deterministic test clock conforming to `Clock<Duration>`.
public final class TestClock: Clock, @unchecked Sendable {
    public struct Instant: InstantProtocol, Comparable {
        public var offset: Duration

        public init(offset: Duration = .zero) {
            self.offset = offset
        }

        public func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        public func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Never>
    }

    private let lock = NSLock()
    private var _now: Instant = Instant()
    private var sleepers: [Sleeper] = []
    public var autoAdvanceThreshold: Duration = .zero

    public init(startOffset: Duration = .zero, autoAdvanceThreshold: Duration = .zero) {
        self._now = Instant(offset: startOffset)
        self.autoAdvanceThreshold = autoAdvanceThreshold
    }

    public var now: Instant {
        lock.withLock { _now }
    }

    public var minimumResolution: Duration {
        .milliseconds(1)
    }

    public var sleeperCount: Int {
        lock.withLock { sleepers.count }
    }

    public func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        let shouldResumeImmediately: Bool = lock.withLock {
            if _now >= deadline {
                return true
            }
            let diff = deadline.offset - _now.offset
            if diff <= autoAdvanceThreshold {
                _now = deadline
                return true
            }
            return false
        }
        if shouldResumeImmediately {
            return
        }

        await withCheckedContinuation { continuation in
            lock.withLock {
                if _now >= deadline {
                    continuation.resume()
                } else {
                    sleepers.append(Sleeper(deadline: deadline, continuation: continuation))
                }
            }
        }
    }

    public func advance(by duration: Duration) {
        let toResume: [CheckedContinuation<Void, Never>] = lock.withLock {
            _now = _now.advanced(by: duration)
            var ready: [CheckedContinuation<Void, Never>] = []
            var remaining: [Sleeper] = []
            for s in sleepers {
                if _now >= s.deadline {
                    ready.append(s.continuation)
                } else {
                    remaining.append(s)
                }
            }
            sleepers = remaining
            return ready
        }

        for c in toResume {
            c.resume()
        }
    }
}
