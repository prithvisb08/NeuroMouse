import Foundation

public final class BlinkDetector: @unchecked Sendable {
    public let earThreshold: Double
    public let minDurationSec: Double
    public let maxDurationSec: Double
    public let doubleBlinkWindowSec: Double
    public var onBlinkClick: (@Sendable (Bool) -> Void)?

    private var isClosed: Bool = false
    private var closureStartTime: Double = 0.0
    private var lastSingleBlinkTime: Double = -100.0
    private var pendingSingleClick: Bool = false

    public init(
        earThreshold: Double = 0.18,
        minDurationMs: Double = 280.0,
        maxDurationMs: Double = 650.0,
        doubleBlinkWindowMs: Double = 400.0,
        onBlinkClick: (@Sendable (Bool) -> Void)? = nil
    ) {
        self.earThreshold = earThreshold
        self.minDurationSec = minDurationMs / 1000.0
        self.maxDurationSec = maxDurationMs / 1000.0
        self.doubleBlinkWindowSec = doubleBlinkWindowMs / 1000.0
        self.onBlinkClick = onBlinkClick
    }

    public func update(leftEAR: Double, rightEAR: Double, timestamp: Double) -> String? {
        let avgEAR = (leftEAR + rightEAR) / 2.0
        var event: String? = nil

        if pendingSingleClick {
            if (timestamp - lastSingleBlinkTime) > doubleBlinkWindowSec {
                pendingSingleClick = false
                event = "left_click"
                onBlinkClick?(false)
            }
        }

        if avgEAR < earThreshold {
            if !isClosed {
                isClosed = true
                closureStartTime = timestamp
            }
        } else {
            if isClosed {
                let duration = timestamp - closureStartTime
                isClosed = false

                if duration >= minDurationSec && duration <= maxDurationSec {
                    if pendingSingleClick && (timestamp - lastSingleBlinkTime) <= doubleBlinkWindowSec {
                        pendingSingleClick = false
                        event = "right_click"
                        onBlinkClick?(true)
                    } else {
                        pendingSingleClick = true
                        lastSingleBlinkTime = timestamp
                    }
                }
            }
        }

        return event
    }
}
