import CarPlay
import UIKit
import AutopalCore

/// CarPlay scene delegate managing the in-car driving-task templates (UI_DESIGN-iOS §7).
///
/// Rules (AGENTS.md & autopal-carplay/SKILL.md):
/// - Template hierarchy depth <= 3 (`CPTabBarTemplate` -> `CPListTemplate`).
/// - No navigation-only APIs (`CPMapTemplate`, `CPNavigationSession` forbidden).
/// - No realtime engine needles/gauges (RPM/speed omitted).
/// - No settings or account setup on CarPlay.
/// - Telemetry updates throttled via `CarPlayThrottle` (<= 1 update / 10 s).
@MainActor
public final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    public static private(set) var shared: CarPlaySceneDelegate?

    private var interfaceController: CPInterfaceController?
    private var healthListTemplate: CPListTemplate?
    private var faultsListTemplate: CPListTemplate?
    private var rootTabBarTemplate: CPTabBarTemplate?

    private var throttle: CarPlayThrottle<VehicleStore>?
    private var lastPresentedCriticalAlertId: AlertId?
    private var currentAlertTemplate: CPAlertTemplate?

    override public init() {
        super.init()
        CarPlaySceneDelegate.shared = self
    }

    // MARK: - CPTemplateApplicationSceneDelegate

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        CarPlaySceneDelegate.shared = self

        setupThrottle()
        setupTemplateHierarchy()

        if let store = AppModel.shared?.vehicleStore {
            update(from: store)
        }
    }

    public func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.throttle = nil
        self.lastPresentedCriticalAlertId = nil
        self.currentAlertTemplate = nil
        if CarPlaySceneDelegate.shared === self {
            CarPlaySceneDelegate.shared = nil
        }
    }

    // MARK: - Template Setup

    private func setupTemplateHierarchy() {
        guard let interfaceController else { return }

        // Tab 1: Health List Template
        let initialHealthSection = CPListSection(items: makeHealthItems(from: nil))
        let healthList = CPListTemplate(title: "Health", sections: [initialHealthSection])
        healthList.tabImage = UIImage(systemName: "cross.case.fill")
        self.healthListTemplate = healthList

        // Tab 2: Faults List Template
        let initialFaultsSection = CPListSection(items: makeFaultsItems(from: nil))
        let faultsList = CPListTemplate(title: "Faults", sections: [initialFaultsSection])
        faultsList.tabImage = UIImage(systemName: "exclamationmark.triangle.fill")
        self.faultsListTemplate = faultsList

        let tabBar = CPTabBarTemplate(templates: [healthList, faultsList])
        self.rootTabBarTemplate = tabBar

        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)
    }

    private func setupThrottle() {
        self.throttle = CarPlayThrottle<VehicleStore>(minInterval: 10.0) { [weak self] store in
            self?.applyStoreUpdate(store)
        }
    }

    // MARK: - Public Update Entry

    /// Called by `AppModel` when vehicle telemetry or alert state changes.
    public func update(from store: VehicleStore) {
        let isAlertTransition = (store.primaryAlert?.id != lastPresentedCriticalAlertId)
        throttle?.submit(store, isAlertTransition: isAlertTransition)
    }

    // MARK: - Throttled Update Application

    private func applyStoreUpdate(_ store: VehicleStore) {
        // 1. Update Health List items
        let healthSection = CPListSection(items: makeHealthItems(from: store))
        healthListTemplate?.updateSections([healthSection])

        // 2. Update Faults List items
        let faultsSection = CPListSection(items: makeFaultsItems(from: store))
        faultsListTemplate?.updateSections([faultsSection])

        // 3. Handle Critical Alerts (UI_DESIGN-iOS §7)
        handleCriticalAlert(from: store)
    }

    // MARK: - Item Builders

    private func makeHealthItems(from store: VehicleStore?) -> [CPListItem] {
        guard let store else {
            let item = CPListItem(text: "Health status", detailText: "Connecting to vehicle…")
            item.setImage(UIImage(systemName: "antenna.radiowaves.left.and.right"))
            return [item]
        }

        var items: [CPListItem] = []

        // 1. Overall Health Verdict
        let verdictItem = CPListItem(text: "Health", detailText: store.verdict.title)
        switch store.verdict.severity {
        case .healthy:
            verdictItem.setImage(UIImage(systemName: "checkmark.circle.fill"))
        case .attention:
            verdictItem.setImage(UIImage(systemName: "exclamationmark.triangle.fill"))
        case .critical:
            verdictItem.setImage(UIImage(systemName: "xmark.octagon.fill"))
        case .notConnected:
            verdictItem.setImage(UIImage(systemName: "bolt.slash.fill"))
        }
        items.append(verdictItem)

        // 2. Coolant Temperature
        let coolantDetail: String
        let coolantIcon: String
        if let c = store.coolantTempC {
            if c >= 105.0 {
                coolantDetail = "\(Int(c)) °C · HOT"
                coolantIcon = "thermometer.high"
            } else if c <= 70.0 {
                coolantDetail = "\(Int(c)) °C · COLD"
                coolantIcon = "thermometer.low"
            } else {
                coolantDetail = "\(Int(c)) °C · NORMAL"
                coolantIcon = "thermometer.medium"
            }
        } else {
            coolantDetail = "Not available"
            coolantIcon = "thermometer"
        }
        let coolantItem = CPListItem(text: "Coolant", detailText: coolantDetail)
        coolantItem.setImage(UIImage(systemName: coolantIcon))
        items.append(coolantItem)

        // 3. Battery Voltage
        let batteryDetail: String
        let batteryIcon: String
        if let v = store.batteryVoltage {
            if v < 12.0 {
                batteryDetail = String(format: "%.1f V · LOW", v)
                batteryIcon = "battery.25"
            } else if v > 15.0 {
                batteryDetail = String(format: "%.1f V · HIGH", v)
                batteryIcon = "battery.100.bolt"
            } else {
                batteryDetail = String(format: "%.1f V · NORMAL", v)
                batteryIcon = "battery.100"
            }
        } else {
            batteryDetail = "Not available"
            batteryIcon = "bolt.fill"
        }
        let batteryItem = CPListItem(text: "Battery", detailText: batteryDetail)
        batteryItem.setImage(UIImage(systemName: batteryIcon))
        items.append(batteryItem)

        // 4. Fuel Level
        let fuelDetail: String
        if let f = store.fuelLevel {
            fuelDetail = "\(Int(f))%"
        } else {
            fuelDetail = "Not available"
        }
        let fuelItem = CPListItem(text: "Fuel", detailText: fuelDetail)
        fuelItem.setImage(UIImage(systemName: "fuelpump.fill"))
        items.append(fuelItem)

        // 5. Diagnostic Readiness
        let readinessDetail: String
        let readinessIcon: String
        if let readiness = store.readiness {
            if readiness.incomplete.isEmpty {
                readinessDetail = "All monitors ready"
                readinessIcon = "checkmark.seal.fill"
            } else {
                readinessDetail = "\(readiness.incomplete.count) incomplete"
                readinessIcon = "clock.badge.checkmark"
            }
        } else {
            readinessDetail = "Reading monitors…"
            readinessIcon = "checklist"
        }
        let readinessItem = CPListItem(text: "Diagnostic monitors", detailText: readinessDetail)
        readinessItem.setImage(UIImage(systemName: readinessIcon))
        items.append(readinessItem)

        return items
    }

    private func makeFaultsItems(from store: VehicleStore?) -> [CPListItem] {
        guard let store else {
            let item = CPListItem(text: "Fault codes", detailText: "Connecting to vehicle…")
            item.setImage(UIImage(systemName: "antenna.radiowaves.left.and.right"))
            return [item]
        }

        if store.storedDtcs.isEmpty {
            let cleanItem = CPListItem(
                text: "No fault codes recorded",
                detailText: "All monitored systems report normal operation."
            )
            cleanItem.setImage(UIImage(systemName: "checkmark.circle.fill"))
            return [cleanItem]
        }

        return store.storedDtcs.map { code in
            let item = CPListItem(
                text: code,
                detailText: "Stored trouble code · Service soon"
            )
            item.setImage(UIImage(systemName: "exclamationmark.triangle.fill"))
            return item
        }
    }

    // MARK: - Critical Alert Modal

    private func handleCriticalAlert(from store: VehicleStore) {
        guard let critical = store.activeAlerts.first(where: { $0.severity == .critical }) else {
            // Dismiss active alert if it cleared
            if currentAlertTemplate != nil {
                interfaceController?.dismissTemplate(animated: true, completion: nil)
                currentAlertTemplate = nil
                lastPresentedCriticalAlertId = nil
            }
            return
        }

        // Present only once per critical alert event
        guard lastPresentedCriticalAlertId != critical.id else { return }

        lastPresentedCriticalAlertId = critical.id

        let okAction = CPAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            self?.currentAlertTemplate = nil
        }

        let alertTemplate = CPAlertTemplate(
            titleVariants: [critical.headline],
            actions: [okAction]
        )
        self.currentAlertTemplate = alertTemplate

        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }
}
