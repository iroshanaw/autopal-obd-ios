import SwiftUI
import AutopalCore

public enum AppearanceSetting: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var id: String { rawValue }
    
    public var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Stores user settings in the App Group container (group.com.autopal.obd)
/// so widgets and Live Activities follow the same appearance and units.
@Observable
@MainActor
public final class SettingsStore {
    private let defaults: UserDefaults
    
    public var appearance: AppearanceSetting {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }
    
    public var temperatureUnit: UnitFormatter.TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: "temperatureUnit") }
    }
    
    public var speedUnit: UnitFormatter.SpeedUnit {
        didSet { defaults.set(speedUnit.rawValue, forKey: "speedUnit") }
    }
    
    public var pressureUnit: UnitFormatter.PressureUnit {
        didSet { defaults.set(pressureUnit.rawValue, forKey: "pressureUnit") }
    }
    
    public var drivingAlertsEnabled: Bool {
        didSet { defaults.set(drivingAlertsEnabled, forKey: "drivingAlertsEnabled") }
    }
    
    public var alertSoundEnabled: Bool {
        didSet { defaults.set(alertSoundEnabled, forKey: "alertSoundEnabled") }
    }
    
    public var muteDurationMinutes: Int {
        didSet { defaults.set(muteDurationMinutes, forKey: "muteDurationMinutes") }
    }
    
    public var setupDone: Bool {
        didSet { defaults.set(setupDone, forKey: "setupDone") }
    }
    
    public var isDemoMode: Bool {
        didSet { defaults.set(isDemoMode, forKey: "isDemoMode") }
    }
    
    public var demoScenario: SimulatedElm327Transport.Scenario {
        didSet { defaults.set(demoScenario.rawValue, forKey: "demoScenario") }
    }
    
    public var vehicleName: String {
        didSet { defaults.set(vehicleName, forKey: "vehicleName") }
    }
    
    public var vehicleEngine: String {
        didSet { defaults.set(vehicleEngine, forKey: "vehicleEngine") }
    }
    
    public var vehicleYear: String {
        didSet { defaults.set(vehicleYear, forKey: "vehicleYear") }
    }
    
    public init(suiteName: String = "group.com.autopal.obd") {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.defaults = defaults
        
        // Appearance
        let savedAppearance = defaults.string(forKey: "appearance")
        self.appearance = savedAppearance.flatMap(AppearanceSetting.init) ?? .system
        
        // Region-based defaults
        let usesMetric = Locale.current.measurementSystem != .us
        
        // Temperature
        if let savedTemp = defaults.string(forKey: "temperatureUnit"),
           let unit = UnitFormatter.TemperatureUnit(rawValue: savedTemp) {
            self.temperatureUnit = unit
        } else {
            self.temperatureUnit = usesMetric ? .celsius : .fahrenheit
        }
        
        // Speed
        if let savedSpeed = defaults.string(forKey: "speedUnit"),
           let unit = UnitFormatter.SpeedUnit(rawValue: savedSpeed) {
            self.speedUnit = unit
        } else {
            self.speedUnit = usesMetric ? .kmh : .mph
        }
        
        // Pressure
        if let savedPressure = defaults.string(forKey: "pressureUnit"),
           let unit = UnitFormatter.PressureUnit(rawValue: savedPressure) {
            self.pressureUnit = unit
        } else {
            self.pressureUnit = usesMetric ? .kpa : .psi
        }
        
        // Switches
        self.drivingAlertsEnabled = defaults.object(forKey: "drivingAlertsEnabled") as? Bool ?? true
        self.alertSoundEnabled = defaults.object(forKey: "alertSoundEnabled") as? Bool ?? true
        self.muteDurationMinutes = defaults.object(forKey: "muteDurationMinutes") as? Int ?? 10
        self.setupDone = defaults.bool(forKey: "setupDone")
        
        // Demo mode (default true for initial review and preview)
        self.isDemoMode = defaults.object(forKey: "isDemoMode") as? Bool ?? true
        
        // Demo scenario
        let savedScenario = defaults.string(forKey: "demoScenario")
        self.demoScenario = savedScenario.flatMap(SimulatedElm327Transport.Scenario.init) ?? .normal
        
        // Vehicle details
        self.vehicleName = defaults.string(forKey: "vehicleName") ?? "Toyota Wigo"
        self.vehicleEngine = defaults.string(forKey: "vehicleEngine") ?? "1.0L 3-cyl (1KR-VE)"
        self.vehicleYear = defaults.string(forKey: "vehicleYear") ?? "2023"
    }
    
    public var unitFormatter: UnitFormatter {
        UnitFormatter(
            temperatureUnit: temperatureUnit,
            speedUnit: speedUnit,
            pressureUnit: pressureUnit
        )
    }
}
