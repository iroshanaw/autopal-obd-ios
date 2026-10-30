import SwiftUI

/// Status chip used for adapter states, severity tags, and connection tags (UI_DESIGN-iOS §4).
public struct StatusChip: View {
    public enum Style {
        case live
        case neutral
        case warning
        case critical
        case brand
    }
    
    public let text: String
    public let systemImage: String?
    public let style: Style
    
    public init(
        text: String,
        systemImage: String? = nil,
        style: Style = .neutral
    ) {
        self.text = text
        self.systemImage = systemImage
        self.style = style
    }
    
    private var fgColor: Color {
        switch style {
        case .live, .brand:
            return AutopalTokens.primary
        case .neutral:
            return AutopalTokens.inkMuted
        case .warning:
            return AutopalTokens.warning
        case .critical:
            return AutopalTokens.critical
        }
    }
    
    private var bgColor: Color {
        switch style {
        case .live, .brand:
            return AutopalTokens.primaryContainer.opacity(0.6)
        case .neutral:
            return AutopalTokens.surfaceHigh
        case .warning:
            return AutopalTokens.warningContainer.opacity(0.8)
        case .critical:
            return AutopalTokens.criticalContainer.opacity(0.8)
        }
    }
    
    public var body: some View {
        HStack(spacing: AutopalTokens.Spacing.s1) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.bold())
            }
            Text(text)
                .font(.caption2.bold())
        }
        .foregroundStyle(fgColor)
        .padding(.horizontal, AutopalTokens.Spacing.s2)
        .padding(.vertical, AutopalTokens.Spacing.s1)
        .background(bgColor)
        .clipShape(Capsule())
    }
}

#Preview("Status Chips") {
    HStack(spacing: 8) {
        StatusChip(text: "LIVE", systemImage: "bolt.fill", style: .live)
        StatusChip(text: "ISO 15765-4", style: .neutral)
        StatusChip(text: "WARNING", systemImage: "exclamationmark.triangle.fill", style: .warning)
        StatusChip(text: "CRITICAL", systemImage: "xmark.octagon.fill", style: .critical)
    }
    .padding()
    .background(AutopalTokens.bg)
}
