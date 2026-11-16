import Foundation
import CoreMedia
import Vision

public struct ProcessedVisionFrame: Sendable {
    public let isFaceDetected: Bool
    public let pose: CraniofacialPose?
    public let leftEAR: Double
    public let rightEAR: Double
    public let mouthOpeningRatio: Double
    public let timestamp: Double

    public init(
        isFaceDetected: Bool,
        pose: CraniofacialPose? = nil,
        leftEAR: Double = 0.3,
        rightEAR: Double = 0.3,
        mouthOpeningRatio: Double = 0.0,
        timestamp: Double = 0.0
    ) {
        self.isFaceDetected = isFaceDetected
        self.pose = pose
        self.leftEAR = leftEAR
        self.rightEAR = rightEAR
        self.mouthOpeningRatio = mouthOpeningRatio
        self.timestamp = timestamp
    }
}

public final class FaceLandmarkProcessor: @unchecked Sendable {
    private let sequenceHandler = VNSequenceRequestHandler()
    private let poseEstimator = CraniofacialPoseEstimator()

    public init() {}

    public func processPixelBuffer(_ pixelBuffer: CVPixelBuffer, timestamp: Double) -> ProcessedVisionFrame {
        let request = VNDetectFaceLandmarksRequest()
        #if targetEnvironment(simulator)
        request.usesCPUOnly = true
        #endif

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .upMirrored)
            guard let results = request.results,
                  let primaryFace = results.first,
                  primaryFace.confidence >= 0.5 else {
                return ProcessedVisionFrame(isFaceDetected: false, timestamp: timestamp)
            }

            let pose = poseEstimator.estimatePose(from: primaryFace)

            // Compute EAR and Mouth Opening from Vision landmarks if present
            var leftEar = 0.3
            var rightEar = 0.3
            var mouthRatio = 0.0
            if let landmarks = primaryFace.landmarks {
                if let leftEye = landmarks.leftEye {
                    leftEar = computeVisionEAR(leftEye.normalizedPoints)
                }
                if let rightEye = landmarks.rightEye {
                    rightEar = computeVisionEAR(rightEye.normalizedPoints)
                }
                mouthRatio = computeVisionMouthRatio(
                    innerLips: landmarks.innerLips?.normalizedPoints,
                    outerLips: landmarks.outerLips?.normalizedPoints,
                    leftEye: landmarks.leftEye?.normalizedPoints,
                    rightEye: landmarks.rightEye?.normalizedPoints
                )
            }

            return ProcessedVisionFrame(
                isFaceDetected: true,
                pose: pose,
                leftEAR: leftEar,
                rightEAR: rightEar,
                mouthOpeningRatio: mouthRatio,
                timestamp: timestamp
            )
        } catch {
            return ProcessedVisionFrame(isFaceDetected: false, timestamp: timestamp)
        }
    }

    private func computeVisionMouthRatio(
        innerLips: [CGPoint]?,
        outerLips: [CGPoint]?,
        leftEye: [CGPoint]?,
        rightEye: [CGPoint]?
    ) -> Double {
        guard let lEye = leftEye?.first, let rEye = rightEye?.first else { return 0.0 }
        let eyeDistance = hypot(Double(lEye.x - rEye.x), Double(lEye.y - rEye.y))
        guard eyeDistance > 1e-4 else { return 0.0 }

        if let inner = innerLips, inner.count >= 4 {
            let ys = inner.map { Double($0.y) }
            let mouthHeight = (ys.max() ?? 0) - (ys.min() ?? 0)
            return mouthHeight / eyeDistance
        } else if let outer = outerLips, outer.count >= 4 {
            let ys = outer.map { Double($0.y) }
            let mouthHeight = (ys.max() ?? 0) - (ys.min() ?? 0)
            return max(0.0, (mouthHeight / eyeDistance) - 0.15)
        }
        return 0.0
    }

    private func computeVisionEAR(_ points: [CGPoint]) -> Double {
        guard points.count >= 6 else { return 0.3 }
        let p1 = points[0]
        let p2 = points[1]
        let p3 = points[2]
        let p4 = points[3]
        let p5 = points[4]
        let p6 = points[5]

        let dv1 = hypot(Double(p2.x - p6.x), Double(p2.y - p6.y))
        let dv2 = hypot(Double(p3.x - p5.x), Double(p3.y - p5.y))
        let dh = hypot(Double(p1.x - p4.x), Double(p1.y - p4.y))

        guard dh > 1e-5 else { return 0.0 }
        return (dv1 + dv2) / (2.0 * dh)
    }
}
