import Foundation
import AVFoundation
import CoreVideo

public final class CameraManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let captureQueue = DispatchQueue(label: "com.headmotion.cameraQueue", qos: .userInteractive)

    public var onFrameCaptured: (@Sendable (CVPixelBuffer, Double) -> Void)?
    public private(set) var isRunning: Bool = false

    public override init() {
        super.init()
    }

    public func setupSession(targetFps: Int = 30) -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
              AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            captureSession.commitConfiguration()
            return false
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()
        return true
    }

    public func start() {
        guard !isRunning else { return }
        captureQueue.async {
            self.captureSession.startRunning()
            self.isRunning = self.captureSession.isRunning
        }
    }

    public func stop() {
        guard isRunning else { return }
        captureQueue.async {
            self.captureSession.stopRunning()
            self.isRunning = false
        }
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = ProcessInfo.processInfo.systemUptime
        onFrameCaptured?(pixelBuffer, timestamp)
    }
}
