import Foundation

/// Entitlements protocol (ARCHITECTURE §6.1).
/// Stage 1 hook: returns true for all features.
/// Replaced by StoreKit 2 in stage 2 without changing screen code.
public protocol Entitlements: Sendable {
    func isPro(_ feature: String) -> Bool
}

public struct Stage1Entitlements: Entitlements {
    public init() {}
    
    public func isPro(_ feature: String) -> Bool {
        // Stage 1: all features unlocked, no paywalls or Pro labels
        return true
    }
}
