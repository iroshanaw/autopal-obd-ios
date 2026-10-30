import SwiftUI
import AutopalCore

/// Adapter connection configuration and management screen (UI_DESIGN-iOS §5).
/// Pushed from Settings or from Home's "Not connected" card.
public struct AdapterSetupView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: AdapterTab = .bluetooth
    @State private var wifiHost: String = "192.168.0.10"
    @State private var wifiPort: String = "35000"
    
    public enum AdapterTab: String, CaseIterable, Identifiable {
        case bluetooth = "Bluetooth"
        case wifi = "Wi-Fi"
        case demo = "Demo"
        
        public var id: String { rawValue }
    }
    
    public init() {}
    
    private var isConnected: Bool {
        appModel.vehicleStore.isConnected
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: AutopalTokens.Spacing.s4) {
                // Connection Status Card
                connectionStatusCard
                
                // Mode Segmented Control (System Liquid Glass)
                Picker("Connection Mode", selection: $selectedTab) {
                    ForEach(AdapterTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                
                // Tab Content
                switch selectedTab {
                case .bluetooth:
                    bluetoothSection
                case .wifi:
                    wifiSection
                case .demo:
                    demoSection
                }
            }
            .padding(AutopalTokens.Spacing.s4)
        }
        .background(AutopalTokens.bg)
        .navigationTitle("OBD Adapter")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Connection Status Card
    
    private var connectionStatusCard: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
            HStack {
                LiveDot(isLive: appModel.vehicleStore.isLive)
                Text(appModel.vehicleStore.isLive ? "LIVE CONNECTED" : isConnected ? "CONNECTING" : "NOT CONNECTED")
                    .font(.caption.bold())
                    .foregroundStyle(appModel.vehicleStore.isLive ? AutopalTokens.primary : AutopalTokens.inkMuted)
                
                Spacer()
                
                if isConnected {
                    Button("Disconnect") {
                        appModel.disconnect()
                    }
                    .font(.caption.bold())
                    .foregroundStyle(AutopalTokens.critical)
                }
            }
            
            if isConnected {
                VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s1) {
                    Text(appModel.vehicleStore.elmVersion ?? "ELM327 OBD-II")
                        .font(.headline)
                        .foregroundStyle(AutopalTokens.ink)
                    
                    if let proto = appModel.vehicleStore.protocolName {
                        Text("Protocol: \(proto)")
                            .font(.footnote)
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                    
                    HStack(spacing: AutopalTokens.Spacing.s2) {
                        Image(systemName: "lock.shield.fill")
                            .font(.caption2)
                            .foregroundStyle(AutopalTokens.primary)
                        Text("Keeps reading when locked")
                            .font(.caption2)
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                    .padding(.top, AutopalTokens.Spacing.s1)
                }
            } else {
                Text("No adapter connected. Choose a connection method below to start reading engine telemetry.")
                    .font(.subheadline)
                    .foregroundStyle(AutopalTokens.inkMuted)
            }
        }
        .padding(AutopalTokens.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
    }
    
    // MARK: - Bluetooth Section
    
    private var bluetoothSection: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
            Text("BLUETOOTH LE ADAPTERS")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.inkMuted)
            
            // Connect to default / known IOS-VLINK button
            Button {
                appModel.connectBle(peripheralName: "IOS-VLINK")
            } label: {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundStyle(AutopalTokens.primary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("IOS-VLINK")
                            .font(.headline)
                            .foregroundStyle(AutopalTokens.ink)
                        Text("Default BLE UART • 18F0 / 2AF0 / 2AF1")
                            .font(.footnote)
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                    
                    Spacer()
                    
                    Text("Connect")
                        .font(.subheadline.bold())
                        .foregroundStyle(AutopalTokens.primary)
                }
                .padding(AutopalTokens.Spacing.s3)
                .background(AutopalTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.sm))
            }
            .buttonStyle(.plain)
            
            // Replug Tip Callout
            HStack(alignment: .top, spacing: AutopalTokens.Spacing.s2) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AutopalTokens.primary)
                    .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Switching from Android?")
                        .font(.footnote.bold())
                        .foregroundStyle(AutopalTokens.ink)
                    Text("Unplug your adapter for 5 seconds and replug before connecting to iPhone. Dual-mode adapters switch from Classic Bluetooth to BLE upon reboot.")
                        .font(.caption)
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
            }
            .padding(AutopalTokens.Spacing.s3)
            .background(AutopalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.sm))
        }
    }
    
    // MARK: - Wi-Fi Section
    
    private var wifiSection: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
            Text("WI-FI OBD-II ADAPTER")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.inkMuted)
            
            VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
                Text("How to connect:")
                    .font(.subheadline.bold())
                    .foregroundStyle(AutopalTokens.ink)
                
                VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
                    Label("Plug your Wi-Fi adapter into the OBD port", systemImage: "1.circle.fill")
                    Label("Join the adapter Wi-Fi in iOS Settings (e.g. WiFi_OBDII)", systemImage: "2.circle.fill")
                    Label("Cellular data remains active for maps and music", systemImage: "3.circle.fill")
                }
                .font(.footnote)
                .foregroundStyle(AutopalTokens.inkMuted)
                
                Divider()
                
                HStack {
                    Text("Host IP")
                        .font(.footnote.bold())
                        .foregroundStyle(AutopalTokens.inkMuted)
                    Spacer()
                    TextField("192.168.0.10", text: $wifiHost)
                        .font(.footnote.monospaced())
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Port")
                        .font(.footnote.bold())
                        .foregroundStyle(AutopalTokens.inkMuted)
                    Spacer()
                    TextField("35000", text: $wifiPort)
                        .font(.footnote.monospaced())
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(AutopalTokens.Spacing.s3)
            .background(AutopalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.sm))
        }
    }
    
    // MARK: - Demo Section
    
    private var demoSection: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
            Text("SIMULATED VEHICLE SCENARIOS")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.inkMuted)
            
            VStack(spacing: AutopalTokens.Spacing.s2) {
                scenarioButton(title: "Normal Driving", subtitle: "All readings within normal limits", scenario: .normal)
                scenarioButton(title: "Engine Overheat", subtitle: "Coolant temperature rises to 118 °C", scenario: .overheat)
                scenarioButton(title: "Charging System Fault", subtitle: "Alternator drops to 11.6 V", scenario: .chargingFault)
                scenarioButton(title: "Vacuum Intake Leak", subtitle: "Total fuel trim elevates to +26%", scenario: .vacuumLeak)
                scenarioButton(title: "Cylinder Misfire", subtitle: "Fault code P0300 stored in ECU", scenario: .misfire)
                scenarioButton(title: "Engine Off at Rest", subtitle: "Ignition off, resting battery 12.4 V", scenario: .ignitionOff)
                scenarioButton(title: "Link Dropout", subtitle: "Simulates connection loss after 5 cycles", scenario: .dropout)
            }
        }
    }
    
    private func scenarioButton(title: String, subtitle: String, scenario: SimulatedElm327Transport.Scenario) -> some View {
        let isCurrent = appModel.settingsStore.isDemoMode && appModel.settingsStore.demoScenario == scenario
        
        return Button {
            appModel.setDemoScenario(scenario)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(isCurrent ? AutopalTokens.primary : AutopalTokens.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
                
                Spacer()
                
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AutopalTokens.primary)
                }
            }
            .padding(AutopalTokens.Spacing.s3)
            .background(AutopalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: AutopalTokens.Radius.sm)
                    .stroke(isCurrent ? AutopalTokens.primary : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
