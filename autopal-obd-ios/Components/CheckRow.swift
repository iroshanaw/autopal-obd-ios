import SwiftUI

/// A row in the Health Check list (UI_DESIGN-iOS §4).
/// Minimum 58 pt height, 30 pt status badge, title in `.headline`, detail in `.footnote`,
/// and monospaced reading on the trailing side.
public struct CheckRow: View {
    public enum Status {
        case pass
        case warning
        case critical
        case running
        case pending
    }
    
    public let title: String
    public let detail: String
    public let value: String?
    public let status: Status
    
    public init(
        title: String,
        detail: String,
        value: String? = nil,
        status: Status = .pass
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.status = status
    }
    
    private var badgeFg: Color {
        switch status {
        case .pass: return AutopalTokens.primary
        case .warning: return AutopalTokens.warning
        case .critical: return AutopalTokens.critical
        case .running, .pending: return AutopalTokens.inkMuted
        }
    }
    
    private var badgeBg: Color {
        switch status {
        case .pass: return AutopalTokens.primaryContainer
        case .warning: return AutopalTokens.warningContainer
        case .critical: return AutopalTokens.criticalContainer
        case .running, .pending: return AutopalTokens.surfaceHigh
        }
    }
    
    public var body: some View {
        HStack(spacing: AutopalTokens.Spacing.s3) {
            // 30 pt badge
            ZStack {
                Circle()
                    .fill(badgeBg)
                    .frame(width: 30, height: 30)
                
                switch status {
                case .pass:
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                        .foregroundStyle(badgeFg)
                case .warning:
                    Image(systemName: "exclamationmark")
                        .font(.caption.bold())
                        .foregroundStyle(badgeFg)
                case .critical:
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(badgeFg)
                case .running:
                    ProgressView()
                        .scaleEffect(0.7)
                case .pending:
                    Circle()
                        .fill(AutopalTokens.outline)
                        .frame(width: 8, height: 8)
                }
            }
            
            // Title & detail
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(AutopalTokens.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(status == .warning || status == .critical ? AutopalTokens.warning : AutopalTokens.inkMuted)
            }
            
            Spacer()
            
            // Value
            if let value {
                Text(value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AutopalTokens.ink)
            }
        }
        .frame(minHeight: 58)
        .padding(.horizontal, AutopalTokens.Spacing.s4)
    }
}

#Preview("Check Rows") {
    VStack(spacing: 0) {
        CheckRow(
            title: "Coolant temperature",
            detail: "Operating within normal range",
            value: "90 °C",
            status: .pass
        )
        Divider()
        CheckRow(
            title: "Charging system",
            detail: "Low alternator voltage detected",
            value: "11.6 V",
            status: .warning
        )
    }
    .background(AutopalTokens.surface)
    .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.md))
    .padding()
    .background(AutopalTokens.bg)
}
