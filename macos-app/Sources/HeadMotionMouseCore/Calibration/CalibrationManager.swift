import Foundation

public struct CalibrationResult: Sendable {
    public let success: Bool
    public let yawBaselineDeg: Double
    public let pitchBaselineDeg: Double
    public let rollBaselineDeg: Double
    public let yawStdDeg: Double
    public let pitchStdDeg: Double
    public let totalFrames: Int
    public let inlierFrames: Int
    public let errorMessage: String?

    public init(
        success: Bool,
        yawBaselineDeg: Double = 0.0,
        pitchBaselineDeg: Double = 0.0,
        rollBaselineDeg: Double = 0.0,
        yawStdDeg: Double = 0.0,
        pitchStdDeg: Double = 0.0,
        totalFrames: Int = 0,
        inlierFrames: Int = 0,
        errorMessage: String? = nil
    ) {
        self.success = success
        self.yawBaselineDeg = yawBaselineDeg
        self.pitchBaselineDeg = pitchBaselineDeg
        self.rollBaselineDeg = rollBaselineDeg
        self.yawStdDeg = yawStdDeg
        self.pitchStdDeg = pitchStdDeg
        self.totalFrames = totalFrames
        self.inlierFrames = inlierFrames
        self.errorMessage = errorMessage
    }
}

public final class CalibrationManager: @unchecked Sendable {
    public let durationSec: Double
    public let minFrames: Int
    public let maxStdDeg: Double

    private var samplesYaw: [Double] = []
    private var samplesPitch: [Double] = []
    private var samplesRoll: [Double] = []
    private var timestamps: [Double] = []

    public private(set) var isActive: Bool = false
    private var startTime: Double?

    public init(durationSec: Double = 2.5, minFrames: Int = 45, maxStdDeg: Double = 1.8) {
        self.durationSec = durationSec
        self.minFrames = minFrames
        self.maxStdDeg = maxStdDeg
    }

    public func start(currentTime: Double) {
        samplesYaw.removeAll()
        samplesPitch.removeAll()
        samplesRoll.removeAll()
        timestamps.removeAll()
        isActive = true
        startTime = currentTime
    }

    public func cancel() {
        isActive = false
        startTime = nil
        samplesYaw.removeAll()
        samplesPitch.removeAll()
        samplesRoll.removeAll()
        timestamps.removeAll()
    }

    public func addSample(
        yaw: Double,
        pitch: Double,
        roll: Double,
        timestamp: Double,
        confidence: Double = 1.0
    ) -> Bool {
        guard isActive, let start = startTime else { return false }

        if confidence >= 0.65 {
            samplesYaw.append(yaw)
            samplesPitch.append(pitch)
            samplesRoll.append(roll)
            timestamps.append(timestamp)
        }

        let elapsed = timestamp - start
        if elapsed >= durationSec {
            isActive = false
            return true
        }
        return false
    }

    public var progress: Double {
        guard isActive, let start = startTime, let lastT = timestamps.last else { return 0.0 }
        let elapsed = lastT - start
        return min(1.0, max(0.0, elapsed / durationSec))
    }

    public static func computeMADInliers(samples: [Double]) -> (inliers: [Double], mean: Double, stdDev: Double) {
        guard !samples.isEmpty else { return ([], 0.0, 0.0) }

        let sortedSamples = samples.sorted()
        let count = sortedSamples.count
        let median = (count % 2 == 0)
            ? (sortedSamples[count / 2 - 1] + sortedSamples[count / 2]) / 2.0
            : sortedSamples[count / 2]

        let absDevs = samples.map { abs($0 - median) }.sorted()
        let mad = (count % 2 == 0)
            ? (absDevs[count / 2 - 1] + absDevs[count / 2]) / 2.0
            : absDevs[count / 2]

        let scale = 1.4826 * mad
        let threshold = 2.5 * scale

        let inliers = samples.filter { abs($0 - median) <= threshold }
        let effectiveInliers = inliers.isEmpty ? samples : inliers

        let mean = effectiveInliers.reduce(0.0, +) / Double(effectiveInliers.count)
        let variance = effectiveInliers.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(effectiveInliers.count)
        let stdDev = sqrt(variance)

        return (effectiveInliers, mean, stdDev)
    }

    public func finalize() -> CalibrationResult {
        isActive = false
        let total = samplesYaw.count

        guard total >= minFrames else {
            return CalibrationResult(
                success: false,
                totalFrames: total,
                errorMessage: "Insufficient frames (\(total)/\(minFrames)). Hold steady and retry."
            )
        }

        let (yawInliers, yawBase, yawStd) = Self.computeMADInliers(samples: samplesYaw)
        let (pitchInliers, pitchBase, pitchStd) = Self.computeMADInliers(samples: samplesPitch)
        let (_, rollBase, _) = Self.computeMADInliers(samples: samplesRoll)

        if yawStd > maxStdDeg || pitchStd > maxStdDeg {
            return CalibrationResult(
                success: false,
                yawBaselineDeg: yawBase,
                pitchBaselineDeg: pitchBase,
                rollBaselineDeg: rollBase,
                yawStdDeg: yawStd,
                pitchStdDeg: pitchStd,
                totalFrames: total,
                inlierFrames: min(yawInliers.count, pitchInliers.count),
                errorMessage: String(format: "Excessive motion detected (yaw std: %.2f°, pitch std: %.2f°, limit: %.1f°).", yawStd, pitchStd, maxStdDeg)
            )
        }

        return CalibrationResult(
            success: true,
            yawBaselineDeg: yawBase,
            pitchBaselineDeg: pitchBase,
            rollBaselineDeg: rollBase,
            yawStdDeg: yawStd,
            pitchStdDeg: pitchStd,
            totalFrames: total,
            inlierFrames: min(yawInliers.count, pitchInliers.count)
        )
    }
}
