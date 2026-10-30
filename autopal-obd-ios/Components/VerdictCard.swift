import SwiftUI

/// Hero verdict card displayed prominently on the Home screen (UI_DESIGN-iOS §4 & §5).
/// Content swaps with opacity transition using AutopalMotion.medium.
public struct VerdictCard: View {
    public let verdict: HealthVerdict
    public let primaryAlertText: String?
    public let customActionTitle: String?
    public let onPrimaryAction: () -> Void
    
    public init(
        verdict: HealthVerdict,
        primaryAlertText: String? = nil,
        activeAlert: AlertItem? = nil,
        actionTitle: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.verdict = verdict
        self.primaryAlertText = activeAlert?.headline ?? primaryAlertText
        self.customActionTitle = actionTitle
        self.onPrimaryAction = action
    }
    
    private var containerColor: Color {
        switch verdict {
        case .healthy:
            return AutopalTokens.primaryContainer
        case .serviceSoon:
            return AutopalTokens.warningContainer
        case .stopAndCheck:
            return AutopalTokens.criticalContainer
        case .notConnected:
            return AutopalTokens.surface
        }
    }
    
    private var accentColor: Color {
        switch verdict {
        case .healthy:
            return AutopalTokens.primary
        case .serviceSoon:
            return AutopalTokens.warning
        case .stopAndCheck:
            return AutopalTokens.critical
        case .notConnected:
            return AutopalTokens.inkMuted
        }
    }
    
    private var iconName: String {
        switch verdict {
        case .healthy:
            return "checkmark.circle.fill"
        case .serviceSoon:
            return "exclamationmark.triangle.fill"
        case .stopAndCheck:
            return "xmark.octagon.fill"
        case .notConnected:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AutopalTokens.Spacing.s3) {
            HStack(alignment: .top) {
                Image(systemName: iconName)
                    .font(.title2.bold())
                    .foregroundStyle(accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(verdict.title)
                        .font(.title3.bold())
                        .foregroundStyle(AutopalTokens.ink)
                    
                    Text(primaryAlertText ?? defaultSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(AutopalTokens.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                StatusChip(
                    text: verdict.badgeLabel,
                    style: chipStyle
                )
            }
            
            // Action button
            Button(action: onPrimaryAction) {
                HStack {
                    Text(actionTitle)
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }
                .foregroundStyle(verdict == .notConnected ? AutopalTokens.onPrimary : AutopalTokens.ink)
                .padding(.horizontal, AutopalTokens.Spacing.s4)
                .padding(.vertical, AutopalTokens.Spacing.s2)
                .background(
                    verdict == .notConnected ? AutopalTokens.primary : AutopalTokens.surfaceHigh
                )
                .clipShape(Capsule())
            }
        }
        .padding(AutopalTokens.Spacing.s4)
        .background(containerColor)
        .clipShape(RoundedRectangle(cornerRadius: AutopalTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AutopalTokens.Radius.lg)
                .stroke(verdict == .notConnected ? AutopalTokens.outline : Color.clear, lineWidth: 1)
        )
    }
    
    private var defaultSubtitle: String {
        switch verdict {
        case .healthy: return "All systems operating normally"
        case .serviceSoon: return "Service required soon"
        case .stopAndCheck: return "Stop vehicle safely and inspect"
        case .notConnected: return "Connect adapter to read telemetry"
        }
    }
    
    private var actionTitle: String {
        if let custom = customActionTitle {
            return custom
        }
        switch verdict {
        case .notConnected:
            return "Connect to adapter"
        default:
            return "Run full health check"
        }
    }
    
    private var chipStyle: StatusChip.Style {
        switch verdict {
        case .healthy: return .brand
        case .serviceSoon: return .warning
        case .stopAndCheck: return .critical
        case .notConnected: return .neutral
        }
    }
}
