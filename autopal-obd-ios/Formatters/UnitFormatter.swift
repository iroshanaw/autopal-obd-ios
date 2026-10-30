import Foundation

/// Formats core metric readings into display units for the UI layer.
/// AutopalCore values are always metric (SI); conversion happens only in the UI.
public struct UnitFormatter: Sendable {
    public enum TemperatureUnit: String, CaseIterable, Identifiable, Sendable {
        case celsius = "celsius"
        case fahrenheit = "fahrenheit"
        
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .celsius: return "°C"
            case .fahrenheit: return "°F"
            }
        }
    }
    
    public enum SpeedUnit: String, CaseIterable, Identifiable, Sendable {
        case kmh = "kmh"
        case mph = "mph"
        
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .kmh: return "km/h"
            case .mph: return "mph"
            }
        }
    }
    
    public enum PressureUnit: String, CaseIterable, Identifiable, Sendable {
        case kpa = "kpa"
        case psi = "psi"
        
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .kpa: return "kPa"
            case .psi: return "psi"
            }
        }
    }
    
    public var temperatureUnit: TemperatureUnit
    public var speedUnit: SpeedUnit
    public var pressureUnit: PressureUnit
    
    public init(
        temperatureUnit: TemperatureUnit = .celsius,
        speedUnit: SpeedUnit = .kmh,
        pressureUnit: PressureUnit = .kpa
    ) {
        self.temperatureUnit = temperatureUnit
        self.speedUnit = speedUnit
        self.pressureUnit = pressureUnit
    }
    
    // MARK: - Conversions
    
    /// Converts a Celsius value to the selected display unit.
    public func convertTemperature(_ celsius: Double) -> Double {
        switch temperatureUnit {
        case .celsius:
            return celsius
        case .fahrenheit:
            return (celsius * 9.0 / 5.0) + 32.0
        }
    }
    
    /// Formats a Celsius value with unit symbol, e.g. "90 °C" or "194 °F".
    public func formatTemperature(_ celsius: Double, includeUnit: Bool = true) -> String {
        let value = convertTemperature(celsius)
        let rounded = Int(round(value))
        return includeUnit ? "\(rounded) \(temperatureUnit.label)" : "\(rounded)"
    }
    
    /// Converts km/h to the selected display unit.
    public func convertSpeed(_ kmh: Double) -> Double {
        switch speedUnit {
        case .kmh:
            return kmh
        case .mph:
            return kmh * 0.621371
        }
    }
    
    /// Formats speed with unit symbol, e.g. "45 km/h" or "28 mph".
    public func formatSpeed(_ kmh: Double, includeUnit: Bool = true) -> String {
        let value = convertSpeed(kmh)
        let rounded = Int(round(value))
        return includeUnit ? "\(rounded) \(speedUnit.label)" : "\(rounded)"
    }
    
    /// Converts kPa to the selected display unit.
    public func convertPressure(_ kpa: Double) -> Double {
        switch pressureUnit {
        case .kpa:
            return kpa
        case .psi:
            return kpa * 0.145038
        }
    }
    
    /// Formats pressure with unit symbol, e.g. "100 kPa" or "14.5 psi".
    public func formatPressure(_ kpa: Double, includeUnit: Bool = true) -> String {
        let value = convertPressure(kpa)
        let formatted = String(format: "%.1f", value)
        return includeUnit ? "\(formatted) \(pressureUnit.label)" : formatted
    }
    
    /// Formats voltage, e.g. "14.1 V".
    public func formatVoltage(_ volts: Double, includeUnit: Bool = true) -> String {
        let formatted = String(format: "%.1f", volts)
        return includeUnit ? "\(formatted) V" : formatted
    }
    
    /// Formats RPM with grouping separator, e.g. "1,750 rpm".
    public func formatRpm(_ rpm: Double, includeUnit: Bool = true) -> String {
        let intVal = Int(round(rpm))
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let text = formatter.string(from: NSNumber(value: intVal)) ?? "\(intVal)"
        return includeUnit ? "\(text) rpm" : text
    }
    
    /// Formats percentage, e.g. "68%".
    public func formatPercentage(_ pct: Double, includeUnit: Bool = true) -> String {
        let rounded = Int(round(pct))
        return includeUnit ? "\(rounded)%" : "\(rounded)"
    }
}
