import WidgetKit
import SwiftUI

/// Timeline provider serving vehicle health snapshots from the App Group container.
struct VehicleHealthTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VehicleHealthEntry {
        VehicleHealthEntry(date: Date(), snapshot: SharedSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (VehicleHealthEntry) -> Void) {
        let snapshot = SharedSnapshot.read()
        completion(VehicleHealthEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VehicleHealthEntry>) -> Void) {
        let snapshot = SharedSnapshot.read()
        let currentEntry = VehicleHealthEntry(date: Date(), snapshot: snapshot)
        
        // Refresh every 15 minutes if not invalidated earlier by the app via reloadTimelines
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

/// Timeline entry holding the shared vehicle state.
struct VehicleHealthEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot
}

/// Vehicle Health Widget for Home Screen, CarPlay and Lock Screen (UI_DESIGN-iOS §8).
public struct VehicleHealthWidget: Widget {
    public static let kind: String = "VehicleHealthWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: VehicleHealthTimelineProvider()) { entry in
            VehicleHealthWidgetView(entry: entry)
        }
        .configurationDisplayName("Vehicle Health")
        .description("Check your vehicle's engine health, coolant temperature, battery, and diagnostic status.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

// MARK: - Widget Root View

struct VehicleHealthWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: VehicleHealthEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenAccessoryView(snapshot: entry.snapshot)
        default:
            SystemSmallHealthView(snapshot: entry.snapshot)
                .containerBackground(AutopalTokens.surface, for: .widget)
        }
    }
}

// MARK: - System Small (Home Screen & CarPlay)

private struct SystemSmallHealthView: View {
    let snapshot: SharedSnapshot

    private var statusColor: Color {
        switch snapshot.verdictSeverity {
        case "critical": return AutopalTokens.critical
        case "warning": return AutopalTokens.warning
        case "healthy": return AutopalTokens.primary
        default: return AutopalTokens.inkMuted
        }
    }

    private var statusContainer: Color {
        switch snapshot.verdictSeverity {
        case "critical": return AutopalTokens.criticalContainer
        case "warning": return AutopalTokens.warningContainer
        case "healthy": return AutopalTokens.primaryContainer
        default: return AutopalTokens.surfaceHigh
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Vehicle Name & Status Pill
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.vehicleName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AutopalTokens.ink)
                    .lineLimit(1)
                
                Spacer(minLength: 4)
                
                Text(snapshot.verdictTitle.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(statusContainer)
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            Divider()
                .overlay(AutopalTokens.outline)

            // Readings
            HStack(spacing: 8) {
                // Coolant Mini Dial
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .stroke(AutopalTokens.gaugeTrack, lineWidth: 3.5)
                            .frame(width: 34, height: 34)

                        Circle()
                            .trim(from: 0, to: min(1.0, max(0.1, Double((snapshot.coolantTempC ?? 80.0) - 40.0) / 80.0)))
                            .stroke(statusColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 34, height: 34)

                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }

                    if let coolant = snapshot.coolantTempC {
                        Text("\(Int(coolant))°C")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(AutopalTokens.ink)
                    } else {
                        Text("--")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AutopalTokens.inkMuted)
                    }
                }

                // Battery and Fuel Metrics
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AutopalTokens.inkMuted)
                        if let v = snapshot.batteryVoltage {
                            Text(String(format: "%.1f V", v))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AutopalTokens.ink)
                        } else {
                            Text("--")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AutopalTokens.inkMuted)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "fuelpump.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AutopalTokens.inkMuted)
                        if let f = snapshot.fuelLevel {
                            Text("\(Int(f))%")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(AutopalTokens.ink)
                        } else {
                            Text("--")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(AutopalTokens.inkMuted)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Alert banner or Status Message
            if let alert = snapshot.alertHeadline {
                Text(alert)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }

            // Data Age (Never implies live data)
            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 8))
                Text("Updated \(snapshot.ageDescription)")
                    .font(.system(size: 9))
            }
            .foregroundStyle(AutopalTokens.inkMuted)
        }
        .padding(4)
    }
}

// MARK: - Accessory Rectangular (Lock Screen)

private struct LockScreenAccessoryView: View {
    let snapshot: SharedSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: snapshot.verdictSeverity == "healthy" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption2)
                Text("\(snapshot.vehicleName) · \(snapshot.verdictTitle)")
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }

            HStack(spacing: 4) {
                if let coolant = snapshot.coolantTempC {
                    Text("\(Int(coolant))°C")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
                Text("·")
                if let v = snapshot.batteryVoltage {
                    Text(String(format: "%.1f V", v))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
                if let f = snapshot.fuelLevel {
                    Text("· \(Int(f))%")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
            }

            Text("Updated \(snapshot.ageDescription)")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}
