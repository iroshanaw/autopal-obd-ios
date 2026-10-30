@preconcurrency import ActivityKit
import Foundation
import SwiftUI

/// Manages the lifecycle of the active driving Live Activity (UI_DESIGN-iOS §8).
/// Starts on `phase == .live`, ends on `phase != .live` (NO_ECU or disconnect).
/// Throttles periodic updates to once every 10–15 seconds, but delivers alert changes immediately.
@MainActor
public final class LiveActivityController {
    public static let shared = LiveActivityController()

    private var currentActivity: Activity<DriveActivityAttributes>?
    private var lastUpdateTime: Date = .distantPast
    private var lastAlertCount: Int = 0
    private var lastVerdictSeverity: String = ""

    private init() {}

    /// Checks if Live Activities are enabled by the user in system settings.
    public var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts a new driving Live Activity if enabled and not already running.
    public func start(vehicleName: String = "Toyota Wigo", vehicleEngine: String = "1KR-VE 1.0L", initialStore: VehicleStore) {
        guard areActivitiesEnabled else { return }

        // Terminate any existing orphan activities first
        endExistingActivities()

        let attributes = DriveActivityAttributes(vehicleName: vehicleName, vehicleEngine: vehicleEngine)
        let state = makeContentState(from: initialStore)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(30))

        do {
            let activity = try Activity<DriveActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            self.currentActivity = activity
            self.lastUpdateTime = Date()
            self.lastAlertCount = initialStore.activeAlerts.count
            self.lastVerdictSeverity = initialStore.verdict.severity == .healthy ? "healthy" : "warning"
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// Updates the Live Activity with the latest vehicle telemetry.
    /// Updates are throttled to at most every 10 seconds unless an alert starts or changes.
    public func update(from store: VehicleStore) {
        guard currentActivity != nil else { return }

        let now = Date()
        let alertCountChanged = store.activeAlerts.count != lastAlertCount
        let currentSeverity = store.verdict.severity == .healthy ? "healthy" : (store.verdict.severity == .critical ? "critical" : "warning")
        let severityChanged = currentSeverity != lastVerdictSeverity
        let intervalPassed = now.timeIntervalSince(lastUpdateTime) >= 10.0

        guard alertCountChanged || severityChanged || intervalPassed else {
            return
        }

        let state = makeContentState(from: store)
        let content = ActivityContent(state: state, staleDate: now.addingTimeInterval(30))

        Task { @MainActor [weak self] in
            guard let self, let current = self.currentActivity else { return }
            await current.update(content)
        }

        self.lastUpdateTime = now
        self.lastAlertCount = store.activeAlerts.count
        self.lastVerdictSeverity = currentSeverity
    }

    /// Ends the current Live Activity when the engine shuts down or connection drops.
    public func end(store: VehicleStore? = nil) {
        guard currentActivity != nil else { return }

        let finalState: DriveActivityAttributes.ContentState
        if let store {
            finalState = makeContentState(from: store)
        } else if let current = currentActivity {
            finalState = current.content.state
        } else {
            return
        }

        let content = ActivityContent(state: finalState, staleDate: nil)

        Task { @MainActor [weak self] in
            guard let self, let current = self.currentActivity else { return }
            self.currentActivity = nil
            await current.end(content, dismissalPolicy: .immediate)
        }

        self.lastUpdateTime = .distantPast
    }

    private func endExistingActivities() {
        Task { @MainActor in
            for activity in Activity<DriveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        self.currentActivity = nil
    }

    private func makeContentState(from store: VehicleStore) -> DriveActivityAttributes.ContentState {
        let severityStr: String
        switch store.verdict.severity {
        case .healthy: severityStr = "healthy"
        case .attention: severityStr = "warning"
        case .critical: severityStr = "critical"
        case .notConnected: severityStr = "notConnected"
        }

        return DriveActivityAttributes.ContentState(
            verdictTitle: store.verdict.title,
            verdictSeverity: severityStr,
            coolantTempC: store.coolantTempC,
            batteryVoltage: store.batteryVoltage,
            engineRpm: store.engineRpm,
            fuelLevel: store.fuelLevel,
            alertHeadline: store.primaryAlert?.headline,
            alertAdvice: store.primaryAlert?.advice,
            timestamp: store.lastUpdated ?? .now
        )
    }
}
