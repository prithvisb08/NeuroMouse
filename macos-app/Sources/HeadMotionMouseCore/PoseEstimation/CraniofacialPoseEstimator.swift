import Foundation
import simd
import Vision

public struct CraniofacialPose: Sendable {
    public let yawDeg: Double
    public let pitchDeg: Double
    public let rollDeg: Double
    public let confidence: Double
    public let txMm: Double
    public let tyMm: Double
    public let tzMm: Double

    public init(
        yawDeg: Double,
        pitchDeg: Double,
        rollDeg: Double,
        confidence: Double = 1.0,
        txMm: Double = 0.0,
        tyMm: Double = 0.0,
        tzMm: Double = 500.0
    ) {
        self.yawDeg = yawDeg
        self.pitchDeg = pitchDeg
        self.rollDeg = rollDeg
        self.confidence = confidence
        self.txMm = txMm
        self.tyMm = tyMm
        self.tzMm = tzMm
    }
}

public struct CraniofacialPoseEstimator: Sendable {
    public init() {}

    /// Refines the VNFaceObservation prior using the Rigid Upper Craniofacial Triad.
    public func estimatePose(from observation: VNFaceObservation) -> CraniofacialPose {
        // Read Vision framework neural network prior
        let visionYaw = observation.yaw?.doubleValue ?? 0.0
        let visionPitch = observation.pitch?.doubleValue ?? 0.0
        let visionRoll = observation.roll?.doubleValue ?? 0.0

        // Convert Vision angles from radians to degrees
        var yawDeg = visionYaw * (180.0 / Double.pi)
        let pitchDeg = visionPitch * (180.0 / Double.pi)
        let rollDeg = visionRoll * (180.0 / Double.pi)

        // Refine with geometric landmarks if available
        if let landmarks = observation.landmarks {
            if let noseCrest = landmarks.noseCrest,
               let leftEye = landmarks.leftEye,
               let rightEye = landmarks.rightEye {
                
                let noseTip = noseCrest.normalizedPoints.last ?? CGPoint.zero
                let leftCanthus = leftEye.normalizedPoints.first ?? CGPoint.zero
                let rightCanthus = rightEye.normalizedPoints.last ?? CGPoint.zero

                let eyeMidX = Double(leftCanthus.x + rightCanthus.x) / 2.0

                // Asymmetry between nose tip and eye midpoint indicates lateral yaw
                let noseDx = Double(noseTip.x) - eyeMidX
                let geometricYawOffset = noseDx * 65.0  // empirical metric scalar

                // Blend Vision neural prior (70%) with upper-facial geometric refinement (30%)
                yawDeg = 0.70 * yawDeg + 0.30 * geometricYawOffset
            }
        }

        let confidence = Double(observation.confidence)
        return CraniofacialPose(
            yawDeg: yawDeg,
            pitchDeg: pitchDeg,
            rollDeg: rollDeg,
            confidence: confidence
        )
    }
}
