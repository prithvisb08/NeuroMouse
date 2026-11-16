import Foundation

/// Smooth quadratic asymptotic dead-zone function ensuring C0 and C1 continuity.
public struct DeadZoneProcessor: Sendable {
    public static func apply(value: Double, threshold: Double, epsilon: Double = 1e-6) -> Double {
        let absVal = abs(value)
        if absVal <= threshold {
            return 0.0
        }
        let diff = absVal - threshold
        let sign = value > 0 ? 1.0 : -1.0
        return sign * (diff * diff) / (diff + epsilon)
    }
}
