import Foundation
import CoreGraphics

public enum DwellState: String, Sendable {
    case idle
    case dwelling
    case triggered
    case cooldown
}

public final class DwellClickDetector: @unchecked Sendable {
    public let dwellRadiusPx: Double
    public let dwellDurationSec: Double
    public let cooldownSec: Double
    public let rearmDistancePx: Double
    public var onClick: (@Sendable (CGPoint, Bool) -> Void)?

    public private(set) var state: DwellState = .idle
    private var anchorPos: CGPoint = .zero
    private var startTime: Double = 0.0
    private var lastClickTime: Double = -100.0
    private var lastClickPos: CGPoint = .zero
    private var lastTime: Double = 0.0
    public var isRightClickArmed: Bool = false

    public init(
        dwellRadiusPx: Double = 18.0,
        dwellDurationMs: Double = 800.0,
        dwellCooldownMs: Double = 1000.0,
        rearmDistancePx: Double = 25.0,
        onClick: (@Sendable (CGPoint, Bool) -> Void)? = nil
    ) {
        self.dwellRadiusPx = dwellRadiusPx
        self.dwellDurationSec = dwellDurationMs / 1000.0
        self.cooldownSec = dwellCooldownMs / 1000.0
        self.rearmDistancePx = rearmDistancePx
        self.onClick = onClick
    }

    public var progress: Double {
        if state == .dwelling {
            return min(1.0, max(0.0, (lastTime - startTime) / dwellDurationSec))
        } else if state == .triggered {
            return 1.0
        }
        return 0.0
    }

    public func cancel() {
        state = .idle
        startTime = 0.0
        isRightClickArmed = false
    }

    public func update(
        cursorPos: CGPoint,
        timestamp: Double,
        isFaceLocked: Bool = true
    ) -> (DwellState, Double) {
        self.lastTime = timestamp

        guard isFaceLocked else {
            cancel()
            return (.idle, 0.0)
        }

        // Cooldown period
        if (timestamp - lastClickTime) < cooldownSec {
            state = .cooldown
            return (.cooldown, 0.0)
        }

        // Re-arm distance check
        let distFromLastClick = hypot(cursorPos.x - lastClickPos.x, cursorPos.y - lastClickPos.y)
        if distFromLastClick < rearmDistancePx && lastClickTime > 0 {
            state = .idle
            return (.idle, 0.0)
        }

        switch state {
        case .idle, .cooldown:
            state = .dwelling
            anchorPos = cursorPos
            startTime = timestamp
            return (.dwelling, 0.0)

        case .dwelling:
            let displacement = hypot(cursorPos.x - anchorPos.x, cursorPos.y - anchorPos.y)
            if displacement > dwellRadiusPx {
                // Movement exceeded dwell radius: re-anchor
                anchorPos = cursorPos
                startTime = timestamp
                return (.dwelling, 0.0)
            }

            let elapsed = timestamp - startTime
            if elapsed >= dwellDurationSec {
                state = .triggered
                lastClickTime = timestamp
                lastClickPos = anchorPos
                let isRight = isRightClickArmed
                isRightClickArmed = false
                onClick?(anchorPos, isRight)
                return (.triggered, 1.0)
            } else {
                return (.dwelling, elapsed / dwellDurationSec)
            }

        case .triggered:
            state = .cooldown
            return (.cooldown, 0.0)
        }
    }
}
