import ActivityKit
import WidgetKit
import SwiftUI

/// Drive Monitor Live Activity for Lock Screen, Dynamic Island, and CarPlay (UI_DESIGN-iOS §8).
public struct DriveLiveActivity: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            // Lock Screen presentation
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded Leading
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AutopalTokens.primary)
                        Text(context.attributes.vehicleName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AutopalTokens.ink)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }

                // Expanded Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.verdictTitle.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(severityColor(context.state.verdictSeverity))

                        if let coolant = context.state.coolantTempC {
                            Text("\(Int(coolant)) °C")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(severityColor(context.state.verdictSeverity))
                        }
                    }
                    .padding(.trailing, 4)
                }

                // Expanded Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        if let alert = context.state.alertHeadline {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(severityColor(context.state.verdictSeverity))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(alert)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(severityColor(context.state.verdictSeverity))
                                    if let advice = context.state.alertAdvice {
                                        Text(advice)
                                            .font(.caption2)
                                            .foregroundStyle(AutopalTokens.inkMuted)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            HStack(spacing: 12) {
                                if let v = context.state.batteryVoltage {
                                    Label(String(format: "%.1f V", v), systemImage: "bolt.fill")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AutopalTokens.ink)
                                }
                                if let f = context.state.fuelLevel {
                                    Label("\(Int(f))%", systemImage: "fuelpump.fill")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AutopalTokens.ink)
                                }
                                if let rpm = context.state.engineRpm {
                                    Label("\(Int(rpm)) rpm", systemImage: "gauge.with.needle")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AutopalTokens.ink)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                // Compact Leading: Mini gauge indicator
                HStack(spacing: 3) {
                    Circle()
                        .fill(severityColor(context.state.verdictSeverity))
                        .frame(width: 8, height: 8)
                    if let coolant = context.state.coolantTempC {
                        Text("\(Int(coolant))°")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(severityColor(context.state.verdictSeverity))
                    }
                }
            } compactTrailing: {
                // Compact Trailing: Status word
                Text(context.state.verdictSeverity == "healthy" ? "OK" : context.state.verdictTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(severityColor(context.state.verdictSeverity))
            } minimal: {
                // Minimal: Status circle
                Circle()
                    .fill(severityColor(context.state.verdictSeverity))
                    .frame(width: 10, height: 10)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<DriveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Vehicle name, verdict chip, and live timestamp
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.open.with.lines.needle.33percent")
                        .font(.subheadline)
                        .foregroundStyle(AutopalTokens.primary)

                    Text(context.attributes.vehicleName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AutopalTokens.ink)
                }

                Spacer()

                HStack(spacing: 6) {
                    Text(context.state.verdictTitle.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(severityContainer(context.state.verdictSeverity))
                        .foregroundStyle(severityColor(context.state.verdictSeverity))
                        .clipShape(Capsule())

                    Text(context.state.timestamp, style: .timer)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
            }

            // Middle Content: Alert or Active Readings
            if let alert = context.state.alertHeadline {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(severityColor(context.state.verdictSeverity))
                        Text(alert)
                            .font(.body.weight(.bold))
                            .foregroundStyle(severityColor(context.state.verdictSeverity))
                    }

                    if let advice = context.state.alertAdvice {
                        Text(advice)
                            .font(.caption)
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                }
            }

            // Bottom Metrics Bar: Coolant, Battery, Fuel, Engine RPM
            HStack(spacing: 16) {
                // Coolant Temp
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.caption)
                        .foregroundStyle(severityColor(context.state.verdictSeverity))
                    if let c = context.state.coolantTempC {
                        Text("\(Int(c)) °C")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AutopalTokens.ink)
                    } else {
                        Text("--")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                }

                // Battery Voltage
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption)
                        .foregroundStyle(AutopalTokens.inkMuted)
                    if let v = context.state.batteryVoltage {
                        Text(String(format: "%.1f V", v))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AutopalTokens.ink)
                    } else {
                        Text("--")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                }

                // Fuel Level
                HStack(spacing: 4) {
                    Image(systemName: "fuelpump.fill")
                        .font(.caption)
                        .foregroundStyle(AutopalTokens.inkMuted)
                    if let f = context.state.fuelLevel {
                        Text("\(Int(f))%")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AutopalTokens.ink)
                    } else {
                        Text("--")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                }

                Spacer()
            }
        }
        .padding(14)
        .activityBackgroundTint(AutopalTokens.surface)
    }
}

// MARK: - Color Helpers

private func severityColor(_ severity: String) -> Color {
    switch severity {
    case "critical": return AutopalTokens.critical
    case "warning": return AutopalTokens.warning
    case "healthy": return AutopalTokens.primary
    default: return AutopalTokens.inkMuted
    }
}

private func severityContainer(_ severity: String) -> Color {
    switch severity {
    case "critical": return AutopalTokens.criticalContainer
    case "warning": return AutopalTokens.warningContainer
    case "healthy": return AutopalTokens.primaryContainer
    default: return AutopalTokens.surfaceHigh
    }
}
