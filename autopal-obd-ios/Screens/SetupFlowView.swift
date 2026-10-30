import SwiftUI
import UserNotifications
import AutopalCore

/// First-run onboarding flow guiding adapter plug-in and initial connection (UI_DESIGN-iOS §5a).
public struct SetupFlowView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var step: SetupStep = .welcome
    @State private var isScanning = false
    
    public enum SetupStep {
        case welcome
        case plugIn
        case connect
        case vehicle
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack {
                switch step {
                case .welcome:
                    welcomeStep
                case .plugIn:
                    plugInStep
                case .connect:
                    connectStep
                case .vehicle:
                    vehicleStep
                }
            }
            .padding(AutopalTokens.Spacing.s4)
            .background(AutopalTokens.bg)
            .toolbar {
                if step != .welcome && step != .vehicle {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") {
                            withAnimation(AutopalMotion.medium) {
                                if step == .connect { step = .plugIn }
                                else if step == .plugIn { step = .welcome }
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Skip") {
                            completeSetup()
                        }
                        .foregroundStyle(AutopalTokens.inkMuted)
                    }
                }
            }
        }
    }
    
    // MARK: - Step 1: Welcome
    
    private var welcomeStep: some View {
        VStack(spacing: AutopalTokens.Spacing.s4) {
            Spacer()
            
            Image(systemName: "gauge.with.needle.fill")
                .font(.system(size: 72))
                .foregroundStyle(AutopalTokens.primary)
            
            Text("Welcome to Autopal")
                .font(.largeTitle.bold())
                .foregroundStyle(AutopalTokens.ink)
            
            Text("Real-time vehicle health, early warning alerts, and plain-English diagnostics from your OBD-II adapter.")
                .font(.body)
                .foregroundStyle(AutopalTokens.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AutopalTokens.Spacing.s3)
            
            Spacer()
            
            VStack(spacing: AutopalTokens.Spacing.s3) {
                Button {
                    withAnimation(AutopalMotion.medium) {
                        step = .plugIn
                    }
                } label: {
                    Text("Set up adapter")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AutopalTokens.primary)
                        .foregroundStyle(Color.black)
                        .clipShape(Capsule())
                }
                
                Button {
                    appModel.connectDemo(scenario: .normal)
                    completeSetup()
                } label: {
                    Text("Try demo first")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AutopalTokens.surface)
                        .foregroundStyle(AutopalTokens.ink)
                        .clipShape(Capsule())
                }
            }
        }
    }
    
    // MARK: - Step 2: Plug In
    
    private var plugInStep: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s4) {
            Text("Step 1 of 3")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.primary)
            
            Text("Plug in your adapter")
                .font(.largeTitle.bold())
                .foregroundStyle(AutopalTokens.ink)
            
            VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
                stepItem(
                    number: "1",
                    title: "Locate your OBD-II port",
                    description: "Usually under the dashboard beneath the steering wheel, or near the fuse box."
                )
                stepItem(
                    number: "2",
                    title: "Plug the adapter in firmly",
                    description: "Push until seated. Most adapters show an illuminated power LED."
                )
                stepItem(
                    number: "3",
                    title: "Turn the ignition ON",
                    description: "Key turned to ON or push-button start activated so the car's computer is powered."
                )
            }
            .padding(AutopalTokens.Spacing.s3)
            .background(AutopalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
            
            Spacer()
            
            Button {
                withAnimation(AutopalMotion.medium) {
                    step = .connect
                    startScanning()
                }
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AutopalTokens.primary)
                    .foregroundStyle(Color.black)
                    .clipShape(Capsule())
            }
        }
    }
    
    private func stepItem(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AutopalTokens.Spacing.s3) {
            Text(number)
                .font(.subheadline.bold())
                .frame(width: 26, height: 26)
                .background(AutopalTokens.primary)
                .foregroundStyle(Color.black)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AutopalTokens.ink)
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(AutopalTokens.inkMuted)
            }
        }
    }
    
    // MARK: - Step 3: Connect
    
    private var connectStep: some View {
        VStack(spacing: AutopalTokens.Spacing.s4) {
            Text("Step 2 of 3")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.primary)
            
            Text("Connecting to adapter")
                .font(.largeTitle.bold())
                .foregroundStyle(AutopalTokens.ink)
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(AutopalTokens.gaugeTrack, lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                ProgressView()
                    .scaleEffect(1.6)
            }
            
            Text(appModel.vehicleStore.isConnected ? "Talking to vehicle ECU..." : "Searching for BLE OBD-II adapter...")
                .font(.headline)
                .foregroundStyle(AutopalTokens.ink)
            
            Text("Ensure Bluetooth is turned on in iOS Settings.")
                .font(.footnote)
                .foregroundStyle(AutopalTokens.inkMuted)
            
            Spacer()
            
            Button("Switch to Demo Mode") {
                appModel.connectDemo(scenario: .normal)
                completeSetup()
            }
            .font(.footnote)
            .foregroundStyle(AutopalTokens.primary)
        }
        .onChange(of: appModel.vehicleStore.isLive) { _, isLive in
            if isLive {
                withAnimation(AutopalMotion.medium) {
                    step = .vehicle
                }
            }
        }
    }
    
    // MARK: - Step 4: Vehicle Summary
    
    private var vehicleStep: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s4) {
            Text("Step 3 of 3")
                .font(.caption.bold())
                .foregroundStyle(AutopalTokens.primary)
            
            Text("Vehicle connected")
                .font(.largeTitle.bold())
                .foregroundStyle(AutopalTokens.ink)
            
            VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
                Text("\(appModel.settingsStore.vehicleYear) \(appModel.settingsStore.vehicleName)")
                    .font(.title3.bold())
                    .foregroundStyle(AutopalTokens.ink)
                Text(appModel.settingsStore.vehicleEngine)
                    .font(.subheadline)
                    .foregroundStyle(AutopalTokens.inkMuted)
                
                if let vin = appModel.vehicleStore.vin {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AutopalTokens.primary)
                        Text("VIN confirmed: \(vin)")
                            .font(.caption.monospaced())
                            .foregroundStyle(AutopalTokens.ink)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(AutopalTokens.Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AutopalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
            
            // Notification Permission Card
            VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
                Label("Driving Health Alerts", systemImage: "bell.badge.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(AutopalTokens.ink)
                
                Text("Allow notifications to receive immediate alerts when coolant overheats or battery voltage drops while driving.")
                    .font(.footnote)
                    .foregroundStyle(AutopalTokens.inkMuted)
                
                Button("Allow Notifications") {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
                }
                .font(.footnote.bold())
                .foregroundStyle(AutopalTokens.primary)
            }
            .padding(AutopalTokens.Spacing.s3)
            .background(AutopalTokens.surface)
            .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
            
            Spacer()
            
            Button {
                completeSetup()
            } label: {
                Text("Go to Dashboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AutopalTokens.primary)
                    .foregroundStyle(Color.black)
                    .clipShape(Capsule())
            }
        }
    }
    
    // MARK: - Actions
    
    private func startScanning() {
        isScanning = true
        appModel.connectBle()
    }
    
    private func completeSetup() {
        appModel.settingsStore.setupDone = true
        dismiss()
    }
}
