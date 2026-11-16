import Foundation
import CoreGraphics

public enum MappingMode: String, Sendable {
    case directAbsolute = "direct_absolute"
    case hybridAbsolute = "hybrid_absolute"
}

public final class MovementEngine: @unchecked Sendable {
    public var screenWidth: Double
    public var screenHeight: Double
    public var yawRangeDeg: Double
    public var pitchRangeDeg: Double
    public var horizontalDeadZone: Double
    public var verticalDeadZone: Double
    public var horizontalSensitivity: Double
    public var verticalSensitivity: Double
    public var invertHorizontal: Bool
    public var invertVertical: Bool
    public var mappingMode: MappingMode
    public var kParallax: Double

    public var baselineYaw: Double = 0.0
    public var baselinePitch: Double = 0.0
    public var baselineRoll: Double = 0.0
    public var gravityDamping: Double = 1.0

    public var baselineNormX: Double = 0.5
    public var baselineNormY: Double = 0.5

    private let filterX: OneEuroFilter
    private let filterY: OneEuroFilter

    private var currentScreenX: Double
    private var currentScreenY: Double

    public init(
        screenWidth: Double = 1920.0,
        screenHeight: Double = 1080.0,
        yawRangeDeg: Double = 15.0,
        pitchRangeDeg: Double = 10.0,
        horizontalDeadZone: Double = 1.2,
        verticalDeadZone: Double = 1.2,
        horizontalSensitivity: Double = 1.0,
        verticalSensitivity: Double = 1.0,
        invertHorizontal: Bool = false,
        invertVertical: Bool = false,
        mappingMode: MappingMode = .hybridAbsolute,
        minCutoff: Double = 1.0,
        beta: Double = 0.04,
        dCutoff: Double = 1.0,
        kParallax: Double = 0.65
    ) {
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.yawRangeDeg = yawRangeDeg
        self.pitchRangeDeg = pitchRangeDeg
        self.horizontalDeadZone = horizontalDeadZone
        self.verticalDeadZone = verticalDeadZone
        self.horizontalSensitivity = horizontalSensitivity
        self.verticalSensitivity = verticalSensitivity
        self.invertHorizontal = invertHorizontal
        self.invertVertical = invertVertical
        self.mappingMode = mappingMode
        self.kParallax = kParallax

        self.filterX = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)
        self.filterY = OneEuroFilter(minCutoff: minCutoff, beta: beta, dCutoff: dCutoff)

        self.currentScreenX = screenWidth / 2.0
        self.currentScreenY = screenHeight / 2.0
    }

    public func setBaseline(yaw: Double, pitch: Double, roll: Double) {
        self.baselineYaw = yaw
        self.baselinePitch = pitch
        self.baselineRoll = roll
        filterX.reset()
        filterY.reset()
        self.currentScreenX = screenWidth / 2.0
        self.currentScreenY = screenHeight / 2.0
    }

    public func setHeadphoneBaseline(normX: Double, normY: Double) {
        self.baselineNormX = normX
        self.baselineNormY = normY
        filterX.reset()
        filterY.reset()
        self.currentScreenX = screenWidth / 2.0
        self.currentScreenY = screenHeight / 2.0
    }

    public func processHeadphone(
        normX: Double,
        normY: Double,
        timestamp: Double
    ) -> CGPoint {
        let effectiveX = invertHorizontal ? (1.0 - normX) : normX
        let effectiveY = invertVertical ? (1.0 - normY) : normY

        var deltaX = effectiveX - baselineNormX
        var deltaY = effectiveY - baselineNormY

        // DeadZone filtering to eliminate hand tremor (1.5% deadzone)
        deltaX = DeadZoneProcessor.apply(value: deltaX, threshold: 0.015)
        deltaY = DeadZoneProcessor.apply(value: deltaY, threshold: 0.015)

        // Sensitivity scaling
        let gainX = horizontalSensitivity * gravityDamping * 2.5
        let gainY = verticalSensitivity * gravityDamping * 2.5

        let scaledDeltaX = deltaX * gainX
        let scaledDeltaY = deltaY * gainY

        // Casiez 1 Euro Filter for buttery smoothing
        let filtDeltaX = filterX.filter(x: scaledDeltaX, timestamp: timestamp)
        let filtDeltaY = filterY.filter(x: scaledDeltaY, timestamp: timestamp)

        // Absolute mapping to screen
        let targetNormX = max(0.0, min(1.0, 0.5 + filtDeltaX))
        let targetNormY = max(0.0, min(1.0, 0.5 + filtDeltaY))

        currentScreenX = targetNormX * screenWidth
        currentScreenY = targetNormY * screenHeight

        return CGPoint(x: currentScreenX, y: currentScreenY)
    }

    public func applyParallaxCompensation(
        yaw: Double,
        pitch: Double,
        tx: Double,
        ty: Double,
        tz: Double
    ) -> (Double, Double) {
        guard abs(tz) > 1e-4 else { return (yaw, pitch) }
        let angXDeg = atan2(tx, tz) * (180.0 / Double.pi)
        let angYDeg = atan2(ty, tz) * (180.0 / Double.pi)
        let yawCorr = yaw - kParallax * angXDeg
        let pitchCorr = pitch - kParallax * angYDeg
        return (yawCorr, pitchCorr)
    }

    public func projectRollHorizon(
        deltaYaw: Double,
        deltaPitch: Double,
        baselineRollDeg: Double
    ) -> (Double, Double) {
        let phiRad = -baselineRollDeg * (Double.pi / 180.0)
        let cosP = cos(phiRad)
        let sinP = sin(phiRad)
        let projYaw = cosP * deltaYaw - sinP * deltaPitch
        let projPitch = sinP * deltaYaw + cosP * deltaPitch
        return (projYaw, projPitch)
    }

    public func process(
        rawYaw: Double,
        rawPitch: Double,
        rawRoll: Double,
        timestamp: Double,
        tx: Double = 0.0,
        ty: Double = 0.0,
        tz: Double = 500.0,
        isHybridPose: Bool = false
    ) -> CGPoint {
        // 1. Translation / Parallax compensation
        let (yaw, pitch): (Double, Double)
        if isHybridPose {
            (yaw, pitch) = applyParallaxCompensation(yaw: rawYaw, pitch: rawPitch, tx: tx, ty: ty, tz: tz)
        } else {
            (yaw, pitch) = (rawYaw, rawPitch)
        }

        // 2. Subtract neutral baseline
        let deltaYaw = yaw - baselineYaw
        let deltaPitch = pitch - baselinePitch

        // 3. Roll horizon rotation
        var (projYaw, projPitch) = projectRollHorizon(
            deltaYaw: deltaYaw,
            deltaPitch: deltaPitch,
            baselineRollDeg: baselineRoll
        )

        // 4. Inversion flags
        if invertHorizontal { projYaw = -projYaw }
        if invertVertical { projPitch = -projPitch }

        // 5. Dead-zone filtering
        let dzYaw = DeadZoneProcessor.apply(value: projYaw, threshold: horizontalDeadZone)
        let dzPitch = DeadZoneProcessor.apply(value: projPitch, threshold: verticalDeadZone)

        // 6. Sensitivity and UI gravity damping
        let effectiveHGain = horizontalSensitivity * gravityDamping
        let effectiveVGain = verticalSensitivity * gravityDamping

        let scaledYaw = dzYaw * effectiveHGain
        let scaledPitch = dzPitch * effectiveVGain

        // 7. 1 Euro Filter
        let filtYaw = filterX.filter(x: scaledYaw, timestamp: timestamp)
        let filtPitch = filterY.filter(x: scaledPitch, timestamp: timestamp)

        // 8. Screen mapping
        let normX = (filtYaw / (2.0 * yawRangeDeg)) + 0.5
        let normY = (filtPitch / (2.0 * pitchRangeDeg)) + 0.5

        if mappingMode == .directAbsolute {
            let targetX = normX * screenWidth
            let targetY = normY * screenHeight
            currentScreenX = max(0.0, min(screenWidth, targetX))
            currentScreenY = max(0.0, min(screenHeight, targetY))
        } else {
            let panSpeed = 12.0
            var panDx = 0.0
            var panDy = 0.0

            if normX < 0.10 {
                panDx = -panSpeed * (0.10 - normX) / 0.10
            } else if normX > 0.90 {
                panDx = panSpeed * (normX - 0.90) / 0.10
            }

            if normY < 0.10 {
                panDy = -panSpeed * (0.10 - normY) / 0.10
            } else if normY > 0.90 {
                panDy = panSpeed * (normY - 0.90) / 0.10
            }

            let centerX = normX * screenWidth
            let centerY = normY * screenHeight
            currentScreenX = max(0.0, min(screenWidth, centerX + panDx))
            currentScreenY = max(0.0, min(screenHeight, centerY + panDy))
        }

        return CGPoint(x: currentScreenX, y: currentScreenY)
    }

    public var currentFilterCutoff: Double {
        return filterX.currentCutoff
    }
}
