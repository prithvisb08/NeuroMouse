import Foundation
import CoreGraphics

public final class GestureEngine: @unchecked Sendable {
    public let dwellDetector: DwellClickDetector
    public let blinkDetector: BlinkDetector
    public let nodDetector: NodDetector

    public var isDwellEnabled: Bool
    public var isBlinkEnabled: Bool
    public var isNodEnabled: Bool
    public var isJawDropEnabled: Bool
    public var jawDropThreshold: Double
    private var jawOpenStartTime: Double = 0.0
    private var jawHasTriggered: Bool = false

    public var onClick: (@Sendable (CGPoint, Bool) -> Void)? {
        didSet {
            dwellDetector.onClick = onClick
        }
    }

    public var onJawDrop: (@Sendable () -> Void)?

    public init(
        dwellRadiusPx: Double = 18.0,
        dwellDurationMs: Double = 800.0,
        dwellCooldownMs: Double = 1000.0,
        rearmDistancePx: Double = 25.0,
        isDwellEnabled: Bool = true,
        isBlinkEnabled: Bool = false,
        isNodEnabled: Bool = false,
        isJawDropEnabled: Bool = false,
        jawDropThreshold: Double = 0.18,
        onClick: (@Sendable (CGPoint, Bool) -> Void)? = nil
    ) {
        self.isDwellEnabled = isDwellEnabled
        self.isBlinkEnabled = isBlinkEnabled
        self.isNodEnabled = isNodEnabled
        self.isJawDropEnabled = isJawDropEnabled
        self.jawDropThreshold = jawDropThreshold
        self.onClick = onClick

        self.dwellDetector = DwellClickDetector(
            dwellRadiusPx: dwellRadiusPx,
            dwellDurationMs: dwellDurationMs,
            dwellCooldownMs: dwellCooldownMs,
            rearmDistancePx: rearmDistancePx,
            onClick: onClick
        )

        self.blinkDetector = BlinkDetector()
        self.nodDetector = NodDetector()

        self.blinkDetector.onBlinkClick = { [weak self] isRight in
            guard let self = self else { return }
            // Blink click dispatches at last known dwell anchor or current pos
            self.onClick?(.zero, isRight)
        }

        self.nodDetector.onNod = { [weak self] in
            guard let self = self else { return }
            self.onClick?(.zero, false)
        }
    }

    public func update(
        cursorPos: CGPoint,
        deltaYawDeg: Double,
        deltaPitchDeg: Double,
        leftEAR: Double,
        rightEAR: Double,
        mouthRatio: Double = 0.0,
        timestamp: Double,
        isFaceLocked: Bool
    ) -> (DwellState, Double) {
        guard isFaceLocked else {
            dwellDetector.cancel()
            nodDetector.reset()
            jawOpenStartTime = 0.0
            jawHasTriggered = false
            return (.idle, 0.0)
        }

        var state: DwellState = .idle
        var prog: Double = 0.0

        if isDwellEnabled {
            (state, prog) = dwellDetector.update(
                cursorPos: cursorPos,
                timestamp: timestamp,
                isFaceLocked: isFaceLocked
            )
        }

        if isBlinkEnabled {
            _ = blinkDetector.update(
                leftEAR: leftEAR,
                rightEAR: rightEAR,
                timestamp: timestamp
            )
        }

        if isNodEnabled {
            let isDwelling = (state == .dwelling)
            _ = nodDetector.update(
                deltaYawDeg: deltaYawDeg,
                deltaPitchDeg: deltaPitchDeg,
                timestamp: timestamp,
                isDwelling: isDwelling
            )
        }

        if isJawDropEnabled {
            if mouthRatio >= jawDropThreshold {
                if jawOpenStartTime == 0.0 {
                    jawOpenStartTime = timestamp
                } else if (timestamp - jawOpenStartTime) >= 0.18 && !jawHasTriggered {
                    jawHasTriggered = true
                    onJawDrop?()
                }
            } else if mouthRatio < (jawDropThreshold * 0.7) {
                jawOpenStartTime = 0.0
                jawHasTriggered = false
            }
        }

        return (state, prog)
    }
}
