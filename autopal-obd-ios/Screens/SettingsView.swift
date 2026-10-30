import SwiftUI
import AutopalCore

/// App configuration, vehicle profile, and units settings screen (UI_DESIGN-iOS §5).
public struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showingResetAlert = false
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            @Bindable var settings = appModel.settingsStore
            
            List {
                // Vehicle Profile Card
                Section {
                    vehicleProfileCard
                }
                
                // Connection
                Section("CONNECTION") {
                    NavigationLink {
                        AdapterSetupView()
                    } label: {
                        HStack {
                            Label("OBD Adapter", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            Text(appModel.vehicleStore.isConnected ? "Connected" : "Not Connected")
                                .font(.footnote)
                                .foregroundStyle(appModel.vehicleStore.isConnected ? AutopalTokens.primary : AutopalTokens.inkMuted)
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { settings.isDemoMode },
                        set: { enabled in
                            if enabled {
                                appModel.connectDemo(scenario: settings.demoScenario)
                            } else {
                                appModel.connectBle()
                            }
                        }
                    )) {
                        Label("Demo Mode", systemImage: "play.circle")
                    }
                }
                
                // Appearance
                Section("APPEARANCE") {
                    Picker("Theme", selection: $settings.appearance) {
                        ForEach(AppearanceSetting.allCases) { opt in
                            Text(opt.label).tag(opt)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Units
                Section("UNITS") {
                    Picker("Temperature", selection: $settings.temperatureUnit) {
                        ForEach(UnitFormatter.TemperatureUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    
                    Picker("Speed & Distance", selection: $settings.speedUnit) {
                        ForEach(UnitFormatter.SpeedUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    
                    Picker("Pressure", selection: $settings.pressureUnit) {
                        ForEach(UnitFormatter.PressureUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                }
                
                // Driving Alerts
                Section("ALERTS") {
                    Toggle("Driving Alerts", isOn: $settings.drivingAlertsEnabled)
                    Toggle("Sound Effects", isOn: $settings.alertSoundEnabled)
                }
                
                // Diagnostics & Data
                Section("DATA & DIAGNOSTICS") {
                    NavigationLink {
                        TrafficLogView()
                    } label: {
                        Label("Raw OBD Traffic Log", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Reset App Data", systemImage: "trash")
                            .foregroundStyle(AutopalTokens.critical)
                    }
                }
                
                // About
                Section("ABOUT") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (Build 1)")
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                    
                    Text("Autopal reads diagnostic OBD-II telemetry directly from your vehicle. It is designed for situational awareness and does not replace a certified mechanic.")
                        .font(.caption)
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
            }
            .background(AutopalTokens.bg)
            .navigationTitle("Settings")
            .confirmationDialog("Reset all app settings?", isPresented: $showingResetAlert, titleVisibility: .visible) {
                Button("Reset All Settings", role: .destructive) {
                    appModel.settingsStore.appearance = .system
                    appModel.settingsStore.drivingAlertsEnabled = true
                    appModel.settingsStore.alertSoundEnabled = true
                    appModel.settingsStore.setupDone = false
                }
            }
        }
    }
    
    // MARK: - Vehicle Profile Card
    
    private var vehicleProfileCard: some View {
        HStack(spacing: AutopalTokens.Spacing.s3) {
            Image(systemName: "car.fill")
                .font(.system(size: 28))
                .foregroundStyle(AutopalTokens.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(appModel.settingsStore.vehicleYear) \(appModel.settingsStore.vehicleName)")
                    .font(.headline)
                    .foregroundStyle(AutopalTokens.ink)
                Text(appModel.settingsStore.vehicleEngine)
                    .font(.footnote)
                    .foregroundStyle(AutopalTokens.inkMuted)
                
                if let vin = appModel.vehicleStore.vin {
                    Text("VIN: \(vin)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, AutopalTokens.Spacing.s1)
    }
}
