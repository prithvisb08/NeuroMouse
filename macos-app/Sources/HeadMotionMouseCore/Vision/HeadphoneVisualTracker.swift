import Foundation
import CoreMedia
import CoreGraphics
import Vision

public struct ProcessedHeadphoneFrame: Sendable {
    public let isDetected: Bool
    public let normalizedX: Double // 0.0 (left) ... 1.0 (right)
    public let normalizedY: Double // 0.0 (top) ... 1.0 (bottom)
    public let boundingBox: CGRect?
    public let confidence: Double
    public let trackingMode: String
    public let timestamp: Double

    public init(
        isDetected: Bool,
        normalizedX: Double = 0.5,
        normalizedY: Double = 0.5,
        boundingBox: CGRect? = nil,
        confidence: Double = 0.0,
        trackingMode: String = "none",
        timestamp: Double = 0.0
    ) {
        self.isDetected = isDetected
        self.normalizedX = normalizedX
        self.normalizedY = normalizedY
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.trackingMode = trackingMode
        self.timestamp = timestamp
    }
}

public final class HeadphoneVisualTracker: @unchecked Sendable {
    private let sequenceHandler = VNSequenceRequestHandler()
    private var trackedObjectObservation: VNDetectedObjectObservation?
    private var isTrackingObject: Bool = false
    private var lastValidCenter: CGPoint = CGPoint(x: 0.5, y: 0.5)

    public init() {}

    public func resetTracking() {
        trackedObjectObservation = nil
        isTrackingObject = false
    }

    public func lockObjectAt(normalizedRect: CGRect) {
        let obs = VNDetectedObjectObservation(boundingBox: normalizedRect)
        self.trackedObjectObservation = obs
        self.isTrackingObject = true
    }

    public func processPixelBuffer(_ pixelBuffer: CVPixelBuffer, timestamp: Double) -> ProcessedHeadphoneFrame {
        // Priority 1: Hand Pose Tracking (Tracks hand holding/moving the headphone)
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 1

        do {
            try sequenceHandler.perform([handRequest], on: pixelBuffer, orientation: .upMirrored)
            if let handObservations = handRequest.results,
               let primaryHand = handObservations.first,
               primaryHand.confidence > 0.25 {

                let recognizedPoints = try? primaryHand.recognizedPoints(.all)
                var validPoints: [CGPoint] = []

                if let points = recognizedPoints {
                    for (_, pt) in points where pt.confidence > 0.20 {
                        validPoints.append(pt.location)
                    }
                }

                if !validPoints.isEmpty {
                    let avgX = validPoints.map(\.x).reduce(0, +) / CGFloat(validPoints.count)
                    let avgY = validPoints.map(\.y).reduce(0, +) / CGFloat(validPoints.count)

                    let minX = validPoints.map(\.x).min() ?? avgX
                    let maxX = validPoints.map(\.x).max() ?? avgX
                    let minY = validPoints.map(\.y).min() ?? avgY
                    let maxY = validPoints.map(\.y).max() ?? avgY

                    let box = CGRect(
                        x: max(0, minX - 0.08),
                        y: max(0, minY - 0.08),
                        width: min(1.0, (maxX - minX) + 0.16),
                        height: min(1.0, (maxY - minY) + 0.16)
                    )

                    let normX = Double(avgX)
                    let normY = 1.0 - Double(avgY)

                    lastValidCenter = CGPoint(x: normX, y: normY)
                    self.trackedObjectObservation = VNDetectedObjectObservation(boundingBox: box)

                    return ProcessedHeadphoneFrame(
                        isDetected: true,
                        normalizedX: normX,
                        normalizedY: normY,
                        boundingBox: box,
                        confidence: Double(primaryHand.confidence),
                        trackingMode: "Headphone Grip",
                        timestamp: timestamp
                    )
                }
            }
        } catch {
            // Hand detection error, fall through
        }

        // Priority 2: Headphone Worn on Head (Tracks headphone position when worn)
        let faceRequest = VNDetectFaceRectanglesRequest()
        do {
            try sequenceHandler.perform([faceRequest], on: pixelBuffer, orientation: .upMirrored)
            if let faces = faceRequest.results,
               let primaryFace = faces.first,
               primaryFace.confidence > 0.30 {
                let box = primaryFace.boundingBox
                let cx = Double(box.midX)
                let cy = 1.0 - Double(box.midY)
                lastValidCenter = CGPoint(x: cx, y: cy)

                return ProcessedHeadphoneFrame(
                    isDetected: true,
                    normalizedX: cx,
                    normalizedY: cy,
                    boundingBox: box,
                    confidence: Double(primaryFace.confidence),
                    trackingMode: "Headphone Worn",
                    timestamp: timestamp
                )
            }
        } catch {
            // Face/Headphone request error, fall through
        }

        // Priority 2: Visual Object Tracking (Follows locked headphone earcup / object)
        if isTrackingObject, let currentObs = trackedObjectObservation {
            let trackRequest = VNTrackObjectRequest(detectedObjectObservation: currentObs)
            trackRequest.trackingLevel = .accurate
            do {
                try sequenceHandler.perform([trackRequest], on: pixelBuffer, orientation: .upMirrored)
                if let results = trackRequest.results as? [VNDetectedObjectObservation],
                   let newObs = results.first,
                   newObs.confidence > 0.25 {
                    self.trackedObjectObservation = newObs
                    let box = newObs.boundingBox
                    let cx = Double(box.midX)
                    let cy = 1.0 - Double(box.midY)
                    lastValidCenter = CGPoint(x: cx, y: cy)

                    return ProcessedHeadphoneFrame(
                        isDetected: true,
                        normalizedX: cx,
                        normalizedY: cy,
                        boundingBox: box,
                        confidence: Double(newObs.confidence),
                        trackingMode: "Headphone Object",
                        timestamp: timestamp
                    )
                }
            } catch {
                self.isTrackingObject = false
            }
        }

        // Priority 3: Foreground Saliency (Dominant moving object / headphone in view)
        let saliencyRequest = VNGenerateObjectnessBasedSaliencyImageRequest()
        do {
            try sequenceHandler.perform([saliencyRequest], on: pixelBuffer, orientation: .upMirrored)
            if let saliencyResult = saliencyRequest.results?.first,
               let salientObjects = saliencyResult.salientObjects,
               let primaryObject = salientObjects.first,
               primaryObject.confidence > 0.35 {
                let box = primaryObject.boundingBox
                let cx = Double(box.midX)
                let cy = 1.0 - Double(box.midY)
                lastValidCenter = CGPoint(x: cx, y: cy)

                return ProcessedHeadphoneFrame(
                    isDetected: true,
                    normalizedX: cx,
                    normalizedY: cy,
                    boundingBox: box,
                    confidence: Double(primaryObject.confidence),
                    trackingMode: "Headphone Saliency",
                    timestamp: timestamp
                )
            }
        } catch {
            // Fall through
        }

        return ProcessedHeadphoneFrame(
            isDetected: false,
            normalizedX: lastValidCenter.x,
            normalizedY: lastValidCenter.y,
            boundingBox: nil,
            confidence: 0.0,
            trackingMode: "none",
            timestamp: timestamp
        )
    }
}
