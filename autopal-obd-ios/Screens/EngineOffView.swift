import SwiftUI
import AutopalCore

/// Displayed when the adapter responds but the vehicle ECU is off (UI_DESIGN-iOS §5).
public struct EngineOffView: View {
    @Environment(AppModel.self) private var appModel
    
    public init() {}
    
    private var batteryVoltageText: String {
        if let v = appModel.vehicleStore.batteryVoltage {
            return String(format: "%.1f", v)
        }
        return "12.4"
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: AutopalTokens.Spacing.s4) {
                // Warning Hero Card
                VStack(spacing: AutopalTokens.Spacing.s3) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AutopalTokens.warning)
                        .padding(.top, AutopalTokens.Spacing.s2)
                    
                    Text("Turn the ignition on")
                        .font(.title2.bold())
                        .foregroundStyle(AutopalTokens.ink)
                    
                    Text("The OBD adapter is responding, but your vehicle's engine computer (ECU) is off.")
                        .font(.subheadline)
                        .foregroundStyle(AutopalTokens.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AutopalTokens.Spacing.s2)
                }
                .padding(AutopalTokens.Spacing.s4)
                .frame(maxWidth: .infinity)
                .background(AutopalTokens.warningContainer)
                .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.lg))
                
                // Battery at Rest
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BATTERY AT REST")
                            .font(.caption.bold())
                            .foregroundStyle(AutopalTokens.inkMuted)
                        Text("Reading from adapter pin 16")
                            .font(.footnote)
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(batteryVoltageText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AutopalTokens.ink)
                        Text("V")
                            .font(.caption.bold())
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                }
                .padding(AutopalTokens.Spacing.s3)
                .background(AutopalTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
                
                // Troubleshooting Steps
                VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
                    Text("CHECK YOUR VEHICLE")
                        .font(.caption.bold())
                        .foregroundStyle(AutopalTokens.inkMuted)
                    
                    VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s2) {
                        troubleshootRow(icon: "1.circle.fill", text: "Turn ignition key to the ON position (dash lights illuminated)")
                        troubleshootRow(icon: "2.circle.fill", text: "Push-button start: press twice without touching the brake")
                        troubleshootRow(icon: "3.circle.fill", text: "Start the engine to read live driving telemetry")
                    }
                }
                .padding(AutopalTokens.Spacing.s3)
                .background(AutopalTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
                
                // Battery protection notice
                HStack(spacing: AutopalTokens.Spacing.s2) {
                    Image(systemName: "battery.100.bolt")
                        .foregroundStyle(AutopalTokens.primary)
                    Text("Autopal stops polling when the ignition is off to protect your battery.")
                        .font(.caption)
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
                .padding(AutopalTokens.Spacing.s2)
                
                // Actions
                VStack(spacing: AutopalTokens.Spacing.s2) {
                    Button("Try Demo Mode") {
                        appModel.connectDemo(scenario: .normal)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AutopalTokens.primary)
                    .controlSize(.regular)
                }
            }
            .padding(AutopalTokens.Spacing.s4)
        }
        .background(AutopalTokens.bg)
    }
    
    private func troubleshootRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: AutopalTokens.Spacing.s2) {
            Image(systemName: icon)
                .foregroundStyle(AutopalTokens.primary)
            Text(text)
                .font(.footnote)
                .foregroundStyle(AutopalTokens.ink)
        }
    }
}
