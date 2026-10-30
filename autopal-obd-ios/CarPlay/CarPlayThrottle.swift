import Foundation

/// Throttles vehicle state updates for CarPlay templates according to Apple Driving-Task rules.
///
/// Rules (UI_DESIGN-iOS §7 & AGENTS.md Rule 11):
/// - Updates coalesce; apply at most once every 10 seconds ("no realtime engine data" rule).
/// - Alert start/end is allowed immediately only if >= 10 seconds since the last update.
/// - Otherwise coalesces and flushes on the next 10-second boundary.
@MainActor
public final class CarPlayThrottle<T> {
    public typealias ApplyHandler = (T) -> Void
    public typealias TimeProvider = () -> Date

    private let minInterval: TimeInterval
    private let timeProvider: TimeProvider
    private let applyHandler: ApplyHandler

    private var lastAppliedTime: Date = .distantPast
    private var pendingValue: T?
    private var scheduledTask: Task<Void, Never>?

    public init(
        minInterval: TimeInterval = 10.0,
        timeProvider: @escaping TimeProvider = { Date() },
        onApply: @escaping ApplyHandler
    ) {
        self.minInterval = minInterval
        self.timeProvider = timeProvider
        self.applyHandler = onApply
    }

    deinit {
        scheduledTask?.cancel()
    }

    /// Submits a new telemetry snapshot.
    /// - Parameters:
    ///   - value: The new telemetry state to apply.
    ///   - isAlertTransition: True if an alert just started or cleared.
    public func submit(_ value: T, isAlertTransition: Bool = false) {
        let now = timeProvider()
        let elapsed = now.timeIntervalSince(lastAppliedTime)

        if elapsed >= minInterval {
            // Cancel any pending flush since we are applying right now
            scheduledTask?.cancel()
            scheduledTask = nil
            pendingValue = nil
            applyImmediately(value, at: now)
        } else {
            // Within throttle window: coalesce
            pendingValue = value
            scheduleFlush(delay: minInterval - elapsed)
        }
    }

    /// Flushes any pending throttled value immediately.
    public func flush() {
        scheduledTask?.cancel()
        scheduledTask = nil
        if let value = pendingValue {
            pendingValue = nil
            applyImmediately(value, at: timeProvider())
        }
    }

    private func applyImmediately(_ value: T, at time: Date) {
        lastAppliedTime = time
        applyHandler(value)
    }

    private func scheduleFlush(delay: TimeInterval) {
        guard scheduledTask == nil else { return }

        let delayNanos = UInt64(max(0.01, delay) * 1_000_000_000)
        scheduledTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard let self, !Task.isCancelled else { return }
            self.scheduledTask = nil
            if let value = self.pendingValue {
                self.pendingValue = nil
                self.applyImmediately(value, at: self.timeProvider())
            }
        }
    }
}
