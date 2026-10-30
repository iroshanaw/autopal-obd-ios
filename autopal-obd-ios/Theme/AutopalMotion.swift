import SwiftUI

/// Animation tokens per UI_DESIGN-iOS §4a.
/// Motion shows what changed; nothing decorative, nothing that keeps moving.
public enum AutopalMotion {
    /// Checkmarks, colour changes (0.15s easeOut)
    public static let fast: Animation = .easeOut(duration: 0.15)
    
    /// Gauge arcs, card state changes, lists (0.25s smooth)
    public static let medium: Animation = .smooth(duration: 0.25)
    
    /// Progress bar, larger layout changes (0.4s smooth)
    public static let slow: Animation = .smooth(duration: 0.4)
    
    /// Alert card entering (spring: response 0.35, damping 0.8)
    public static let alert: Animation = .spring(response: 0.35, dampingFraction: 0.8)
    
    /// Duration constants in seconds for custom animators
    public enum Duration {
        public static let fast: Double = 0.15
        public static let medium: Double = 0.25
        public static let slow: Double = 0.4
        public static let ringPulse: Double = 0.3
        public static let liveBreathing: Double = 1.6
    }
}
