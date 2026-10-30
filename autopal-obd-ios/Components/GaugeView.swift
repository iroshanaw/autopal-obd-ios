import SwiftUI

/// Animatable arc shape for gauge progress.
public struct GaugeArcShape: Shape, Sendable {
    public var fraction: Double
    
    public init(fraction: Double) {
        self.fraction = fraction
    }
    
    public var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }
    
    public nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let startAngle = Angle.degrees(135)
        let totalSpan = 270.0
        let endAngle = Angle.degrees(135 + (totalSpan * min(max(fraction, 0.0), 1.0)))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

/// A gauge tile displaying live vehicle readings (UI_DESIGN-iOS §4 & §4a).
/// Animatable arc with AutopalMotion.medium, instantaneous numeric updates,
/// and a single ring pulse animation upon entering warning/critical states.
public struct GaugeView: View {
    public enum Status: Sendable, Equatable {
        case normal
        case warning
        case critical
        case stale
    }
    
    public let title: String
    public let valueText: String
    public let unitText: String
    public let fraction: Double
    public let status: Status
    public let caption: String?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 1.0
    @State private var previousStatus: Status = .normal
    
    public init(
        title: String,
        valueText: String,
        unitText: String,
        fraction: Double,
        status: Status = .normal,
        caption: String? = nil
    ) {
        self.title = title
        self.valueText = valueText
        self.unitText = unitText
        self.fraction = fraction
        self.status = status
        self.caption = caption
    }
    
    public init(
        title: String,
        value: Double?,
        unit: String,
        minValue: Double,
        maxValue: Double,
        warningThreshold: Double? = nil,
        criticalThreshold: Double? = nil,
        isWarningBelow: Bool = false,
        decimalPlaces: Int = 0,
        hasRedline: Bool = false,
        redlineStart: Double? = nil,
        caption: String? = nil
    ) {
        self.title = title
        self.unitText = unit
        self.caption = caption
        
        guard let value else {
            self.valueText = "—"
            self.fraction = 0.0
            self.status = .stale
            return
        }
        
        if decimalPlaces > 0 {
            self.valueText = String(format: "%.\(decimalPlaces)f", value)
        } else {
            self.valueText = "\(Int(value.rounded()))"
        }
        
        let range = maxValue - minValue
        let clampedVal = min(max(value, minValue), maxValue)
        self.fraction = range > 0 ? (clampedVal - minValue) / range : 0.0
        
        if isWarningBelow {
            if let crit = criticalThreshold, value <= crit {
                self.status = .critical
            } else if let warn = warningThreshold, value <= warn {
                self.status = .warning
            } else {
                self.status = .normal
            }
        } else {
            if let crit = criticalThreshold, value >= crit {
                self.status = .critical
            } else if let warn = warningThreshold, value >= warn {
                self.status = .warning
            } else {
                self.status = .normal
            }
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .normal: return AutopalTokens.gaugeNormal
        case .warning: return AutopalTokens.gaugeWarning
        case .critical: return AutopalTokens.gaugeCritical
        case .stale: return AutopalTokens.inkStale
        }
    }
    
    private var textColor: Color {
        switch status {
        case .normal: return AutopalTokens.ink
        case .warning: return AutopalTokens.warning
        case .critical: return AutopalTokens.critical
        case .stale: return AutopalTokens.inkStale
        }
    }
    
    public var body: some View {
        VStack(spacing: AutopalTokens.Spacing.s2) {
            // Header
            HStack {
                Text(title)
                    .font(.footnote.bold())
                    .foregroundStyle(AutopalTokens.inkMuted)
                Spacer()
                if let caption {
                    Text(caption)
                        .font(.caption2.bold())
                        .foregroundStyle(statusColor)
                }
            }
            
            // Gauge Arc Area
            ZStack {
                // Background Track Arc
                GaugeArcShape(fraction: 1.0)
                    .stroke(
                        AutopalTokens.gaugeTrack,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                
                // Active Value Arc
                GaugeArcShape(fraction: fraction)
                    .stroke(
                        statusColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .animation(AutopalMotion.medium, value: fraction)
                
                // Value and Unit inside arc
                VStack(spacing: 0) {
                    Text(valueText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                    
                    Text(unitText)
                        .font(.caption2.bold())
                        .foregroundStyle(AutopalTokens.inkMuted)
                }
                .offset(y: 4)
            }
            .frame(width: 110, height: 95)
            .scaleEffect(pulseScale)
        }
        .padding(AutopalTokens.Spacing.s3)
        .background(AutopalTokens.surface)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AutopalTokens.Radius.md)
                .stroke(
                    status == .critical ? AutopalTokens.critical : (status == .warning ? AutopalTokens.warning : Color.clear),
                    lineWidth: status == .critical || status == .warning ? 1.5 : 0
                )
        )
        .onChange(of: status) { oldVal, newVal in
            guard !reduceMotion else { return }
            // Trigger single ring pulse when entering warning or critical
            if (newVal == .warning || newVal == .critical) && oldVal == .normal {
                withAnimation(.easeInOut(duration: 0.15)) {
                    pulseScale = 1.04
                }
                withAnimation(.easeInOut(duration: 0.15).delay(0.15)) {
                    pulseScale = 1.0
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(valueText) \(unitText), \(statusAccessibilityDescription)")
    }
    
    private var statusAccessibilityDescription: String {
        switch status {
        case .normal: return "normal"
        case .warning: return "warning, attention required"
        case .critical: return "critical alert"
        case .stale: return "stale data"
        }
    }
}
