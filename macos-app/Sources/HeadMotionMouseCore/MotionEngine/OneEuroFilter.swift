import Foundation

/// Casiez One Euro (1€) velocity-adaptive low-pass filter.
public final class OneEuroFilter: @unchecked Sendable {
    public let minCutoff: Double
    public let beta: Double
    public let dCutoff: Double

    private var xPrev: Double?
    private var dxPrev: Double = 0.0
    private var tPrev: Double?

    public init(minCutoff: Double = 1.0, beta: Double = 0.04, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    private func smoothingFactor(cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)
    }

    public func filter(x: Double, timestamp: Double) -> Double {
        guard let prevX = xPrev, let prevT = tPrev else {
            xPrev = x
            dxPrev = 0.0
            tPrev = timestamp
            return x
        }

        var dt = timestamp - prevT
        if dt <= 0.0 {
            dt = 1.0 / 30.0
        }

        let rawDx = (x - prevX) / dt
        let alphaD = smoothingFactor(cutoff: dCutoff, dt: dt)
        let filteredDx = alphaD * rawDx + (1.0 - alphaD) * dxPrev

        let dynamicCutoff = minCutoff + beta * abs(filteredDx)
        let alpha = smoothingFactor(cutoff: dynamicCutoff, dt: dt)

        let filteredX = alpha * x + (1.0 - alpha) * prevX

        self.xPrev = filteredX
        self.dxPrev = filteredDx
        self.tPrev = timestamp

        return filteredX
    }

    public func reset() {
        xPrev = nil
        dxPrev = 0.0
        tPrev = nil
    }

    public var currentCutoff: Double {
        return minCutoff + beta * abs(dxPrev)
    }
}
