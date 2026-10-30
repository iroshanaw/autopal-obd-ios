import SwiftUI

/// Live breathing indicator dot (UI_DESIGN-iOS §4a).
/// Opacity 1.0 <-> 0.45, 1.6 s, repeating, ONLY while live; static when stale/disconnected.
/// The only looping animation in the app. Stops when Reduce Motion is enabled.
public struct LiveDot: View {
    public let isLive: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed: Bool = false
    
    public init(isLive: Bool) {
        self.isLive = isLive
    }
    
    public var body: some View {
        Circle()
            .fill(isLive ? AutopalTokens.primary : AutopalTokens.inkMuted)
            .frame(width: 8, height: 8)
            .opacity(isLive && !reduceMotion && isDimmed ? 0.45 : 1.0)
            .onAppear {
                updateAnimation()
            }
            .onChange(of: isLive) { _, _ in
                updateAnimation()
            }
            .onChange(of: reduceMotion) { _, _ in
                updateAnimation()
            }
    }
    
    private func updateAnimation() {
        if isLive && !reduceMotion {
            withAnimation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true)
            ) {
                isDimmed = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                isDimmed = false
            }
        }
    }
}

#Preview("Live Dot") {
    HStack(spacing: 16) {
        HStack(spacing: 6) {
            LiveDot(isLive: true)
            Text("LIVE")
                .font(.caption2.bold())
                .foregroundStyle(AutopalTokens.ink)
        }
        HStack(spacing: 6) {
            LiveDot(isLive: false)
            Text("OFFLINE")
                .font(.caption2.bold())
                .foregroundStyle(AutopalTokens.inkMuted)
        }
    }
    .padding()
    .background(AutopalTokens.bg)
}
