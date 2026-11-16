import Foundation

public final class NodDetector: @unchecked Sendable {
    public let pitchThresholdDeg: Double
    public let maxDurationSec: Double
    public let maxYawDevDeg: Double
    public var onNod: (@Sendable () -> Void)?

    private enum State {
        case idle
        case pitchDown
    }

    private var state: State = .idle
    private var startTime: Double = 0.0
    private var peakPitch: Double = 0.0
    private var lastNodTime: Double = -10.0

    public init(
        pitchThresholdDeg: Double = 4.5,
        maxDurationSec: Double = 0.45,
        maxYawDevDeg: Double = 2.0,
        onNod: (@Sendable () -> Void)? = nil
    ) {
        self.pitchThresholdDeg = pitchThresholdDeg
        self.maxDurationSec = maxDurationSec
        self.maxYawDevDeg = maxYawDevDeg
        self.onNod = onNod
    }

    public func reset() {
        state = .idle
        startTime = 0.0
        peakPitch = 0.0
    }

    public func update(
        deltaYawDeg: Double,
        deltaPitchDeg: Double,
        timestamp: Double,
        isDwelling: Bool = false
    ) -> Bool {
        if isDwelling {
            reset()
            return false
        }

        if (timestamp - lastNodTime) < 0.8 {
            return false
        }

        if abs(deltaYawDeg) > maxYawDevDeg {
            reset()
            return false
        }

        switch state {
        case .idle:
            if deltaPitchDeg >= pitchThresholdDeg {
                state = .pitchDown
                startTime = timestamp
                peakPitch = deltaPitchDeg
            }
        case .pitchDown:
            let elapsed = timestamp - startTime
            if elapsed > maxDurationSec {
                reset()
                return false
            }

            if deltaPitchDeg > peakPitch {
                peakPitch = deltaPitchDeg
            }

            if deltaPitchDeg <= 1.5 && peakPitch >= pitchThresholdDeg {
                lastNodTime = timestamp
                reset()
                onNod?()
                return true
            }
        }
        return false
    }
}
