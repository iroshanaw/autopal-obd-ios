import SwiftUI
import AutopalCore

/// Main telemetry dashboard screen displaying health verdict and 2×2 gauges (UI_DESIGN-iOS §5).
public struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var selectedTab: Int
    @State private var showingAdapterSheet = false
    
    public init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
    }
    
    private var isConnected: Bool {
        appModel.vehicleStore.isConnected
    }
    
    private var isNoEcu: Bool {
        appModel.vehicleStore.isNoEcu
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if isNoEcu {
                    EngineOffView()
                } else {
                    mainContent
                }
            }
            .background(AutopalTokens.bg)
            .navigationTitle(appModel.settingsStore.vehicleName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    statusHeader
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AdapterSetupView()
                    } label: {
                        Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .foregroundStyle(isConnected ? AutopalTokens.primary : AutopalTokens.inkMuted)
                    }
                }
            }
            .sheet(isPresented: $showingAdapterSheet) {
                NavigationStack {
                    AdapterSetupView()
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: AutopalTokens.Spacing.s4) {
                // Verdict or Disconnected Card
                if isConnected {
                    VerdictCard(
                        verdict: appModel.vehicleStore.verdict,
                        activeAlert: appModel.vehicleStore.primaryAlert,
                        actionTitle: "Run Health Check",
                        action: { selectedTab = 1 }
                    )
                } else {
                    disconnectedCard
                }
                
                // 2x2 Gauges Grid
                gaugesGrid
                
                // Additional Readings
                if isConnected {
                    moreReadingsSection
                }
            }
            .padding(AutopalTokens.Spacing.s4)
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        HStack(spacing: 6) {
            LiveDot(isLive: appModel.vehicleStore.isLive)
            Text(statusLineText)
                .font(.caption2.bold())
                .foregroundStyle(appModel.vehicleStore.isLive ? AutopalTokens.ink : AutopalTokens.inkMuted)
        }
    }
    
    private var statusLineText: String {
        if appModel.vehicleStore.isLive {
            if appModel.settingsStore.isDemoMode {
                return "DEMO • \(appModel.settingsStore.demoScenario.rawValue.uppercased())"
            } else {
                return "LIVE • BLE • \(appModel.vehicleStore.elmVersion ?? "OBD")"
            }
        } else if isConnected {
            return "CONNECTING"
        } else {
            return "OFFLINE"
        }
    }
    
    // MARK: - Disconnected Card
    
    private var disconnectedCard: some View {
        VStack(spacing: AutopalTokens.Spacing.s3) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 36))
                .foregroundStyle(AutopalTokens.inkMuted)
                .padding(.top, AutopalTokens.Spacing.s2)
            
            Text("Not Connected")
                .font(.title3.bold())
                .foregroundStyle(AutopalTokens.ink)
            
            Text("Connect your OBD adapter to view live engine telemetry and driving health alerts.")
                .font(.footnote)
                .foregroundStyle(AutopalTokens.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AutopalTokens.Spacing.s2)
            
            HStack(spacing: AutopalTokens.Spacing.s3) {
                Button {
                    showingAdapterSheet = true
                } label: {
                    Text("Connect")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AutopalTokens.primary)
                        .foregroundStyle(Color.black)
                        .clipShape(Capsule())
                }
                
                Button {
                    appModel.connectDemo(scenario: .normal)
                } label: {
                    Text("Try Demo")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AutopalTokens.surface)
                        .foregroundStyle(AutopalTokens.ink)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, AutopalTokens.Spacing.s1)
        }
        .padding(AutopalTokens.Spacing.s4)
        .frame(maxWidth: .infinity)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.lg))
    }
    
    // MARK: - 2x2 Gauges Grid
    
    private var gaugesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AutopalTokens.Spacing.s3) {
            // Engine RPM
            GaugeView(
                title: "Engine",
                value: appModel.vehicleStore.engineRpm,
                unit: "rpm",
                minValue: 0,
                maxValue: 7000,
                warningThreshold: 5500,
                criticalThreshold: 6200,
                hasRedline: true,
                redlineStart: 6200
            )
            
            // Coolant Temperature
            let coolant = appModel.vehicleStore.coolantTempC
            let dispCoolant = coolant.map { appModel.settingsStore.unitFormatter.convertTemperature($0) }
            let coolantUnit = appModel.settingsStore.temperatureUnit.label
            GaugeView(
                title: "Coolant",
                value: dispCoolant,
                unit: coolantUnit,
                minValue: appModel.settingsStore.temperatureUnit == .celsius ? -40 : -40,
                maxValue: appModel.settingsStore.temperatureUnit == .celsius ? 140 : 280,
                warningThreshold: appModel.settingsStore.temperatureUnit == .celsius ? 105 : 221,
                criticalThreshold: appModel.settingsStore.temperatureUnit == .celsius ? 115 : 239
            )
            
            // Battery Voltage
            GaugeView(
                title: "Battery",
                value: appModel.vehicleStore.batteryVoltage,
                unit: "V",
                minValue: 10.0,
                maxValue: 16.0,
                warningThreshold: 12.0,
                criticalThreshold: 11.5,
                isWarningBelow: true,
                decimalPlaces: 1
            )
            
            // Fuel Level
            GaugeView(
                title: "Fuel",
                value: appModel.vehicleStore.fuelLevel,
                unit: "%",
                minValue: 0,
                maxValue: 100,
                warningThreshold: 15,
                criticalThreshold: 5,
                isWarningBelow: true
            )
        }
    }
    
    // MARK: - More Readings Section
    
    private var moreReadingsSection: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
            Text("MORE READINGS")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.inkMuted)
                .padding(.horizontal, AutopalTokens.Spacing.s1)
            
            VStack(spacing: 0) {
                // Intake Air Temp
                let intakeC = appModel.vehicleStore.intakeTemp
                let intakeText = intakeC.map { appModel.settingsStore.unitFormatter.formatTemperature($0) } ?? "—"
                readingRow(title: "Intake Air Temperature", value: intakeText)
                
                Divider().padding(.leading, 16)
                
                // Engine Load
                let load = appModel.vehicleStore.engineLoad
                readingRow(title: "Calculated Engine Load", value: load.map { "\(Int($0))%" } ?? "—")
                
                Divider().padding(.leading, 16)
                
                // Throttle Position
                let throttle = appModel.vehicleStore.throttle
                readingRow(title: "Throttle Position", value: throttle.map { "\(Int($0))%" } ?? "—")
                
                Divider().padding(.leading, 16)
                
                // Short Term Fuel Trim
                let stft = appModel.vehicleStore.stft
                readingRow(title: "Short Term Fuel Trim", value: stft.map { String(format: "%+.1f%%", $0) } ?? "—")
                
                Divider().padding(.leading, 16)
                
                // Long Term Fuel Trim
                let ltft = appModel.vehicleStore.ltft
                readingRow(title: "Long Term Fuel Trim", value: ltft.map { String(format: "%+.1f%%", $0) } ?? "—")
                
                Divider().padding(.leading, 16)
                
                // MAF
                let maf = appModel.vehicleStore.maf
                readingRow(title: "Mass Air Flow (MAF)", value: maf.map { String(format: "%.1f g/s", $0) } ?? "—")
            }
            .background(AutopalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
        }
    }
    
    private func readingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AutopalTokens.ink)
            Spacer()
            Text(value)
                .font(.footnote.monospaced())
                .foregroundStyle(AutopalTokens.inkMuted)
        }
        .padding(.horizontal, AutopalTokens.Spacing.s3)
        .padding(.vertical, 12)
    }
}
