import Foundation
import SwiftUI
import CoreGraphics
import AppKit

@MainActor
public final class AppState: ObservableObject {
    public let settingsStore: SettingsStore
    public let permissions: PermissionManager

    // Core engines
    public let camera: CameraManager
    public let landmarkProcessor: FaceLandmarkProcessor
    public let headphoneTracker: HeadphoneVisualTracker
    public let movementEngine: MovementEngine
    public let calibrationManager: CalibrationManager
    public let cursorController: CursorController
    public let gravityEngine: AccessibilityGravityEngine
    public let gestureEngine: GestureEngine
    public let headphoneDetector: HeadphoneTapDetector
    public let headphoneMonitor: HeadphoneConnectionMonitor

    // Real-time telemetry readouts
    @Published public var fps: Double = 30.0
    @Published public var latencyMs: Double = 0.0
    @Published public var currentYaw: Double = 0.0
    @Published public var currentPitch: Double = 0.0
    @Published public var currentRoll: Double = 0.0
    @Published public var filterCutoffHz: Double = 1.0

    @Published public var isFaceLocked: Bool = false
    @Published public var isHeadphoneLocked: Bool = false
    @Published public var headphoneNormalizedPos: CGPoint = CGPoint(x: 0.5, y: 0.5)
    @Published public var headphoneBoundingBox: CGRect? = nil
    @Published public var trackingModeName: String = "Headphone Grip"
    @Published public var isTrackingActive: Bool = false
    @Published public var isCalibrating: Bool = false
    @Published public var calibrationProgress: Double = 0.0
    @Published public var dwellProgress: Double = 0.0
    @Published public var dwellState: DwellState = .idle
    @Published public var statusMessage: String = "Ready"
    @Published public var isDragging: Bool = false

    // Latest camera frame representation for preview
    @Published public var latestPixelBuffer: CVPixelBuffer?
    @Published public var isPrivacyShutterActive: Bool = false

    // Navigation and sheet presentation state
    @Published public var showingCalibrationSheet: Bool = false
    @Published public var showingSettingsSheet: Bool = false

    private var lastFrameTime: Double = 0.0
    private var hasInitializedBaseline: Bool = false
    private let hotKeyBox = HotKeyMonitorBox()

    private final class HotKeyMonitorBox: @unchecked Sendable {
        var monitor: Any?
    }

    private struct SendableBuffer: @unchecked Sendable {
        let buffer: CVPixelBuffer
    }

    public init() {
        self.settingsStore = SettingsStore()
        self.permissions = PermissionManager()

        let s = settingsStore.settings
        let screen = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)

        self.movementEngine = MovementEngine(
            screenWidth: Double(screen.width),
            screenHeight: Double(screen.height),
            yawRangeDeg: s.yawRangeDeg,
            pitchRangeDeg: s.pitchRangeDeg,
            horizontalDeadZone: s.horizontalDeadZoneDeg,
            verticalDeadZone: s.verticalDeadZoneDeg,
            horizontalSensitivity: s.horizontalSensitivity,
            verticalSensitivity: s.verticalSensitivity,
            invertHorizontal: s.invertHorizontal,
            invertVertical: s.invertVertical,
            mappingMode: MappingMode(rawValue: s.mappingMode) ?? .hybridAbsolute,
            minCutoff: s.oneEuroMinCutoff,
            beta: s.oneEuroBeta,
            dCutoff: s.oneEuroDCutoff,
            kParallax: s.parallaxCompensation
        )

        self.calibrationManager = CalibrationManager()
        self.cursorController = CursorController(
            physicalOverridePause: s.physicalMouseOverridePause,
            overrideThresholdPx: s.physicalOverrideThresholdPx
        )
        self.gravityEngine = AccessibilityGravityEngine(
            isEnabled: s.uiGravityEnabled,
            dampingFactor: s.uiGravityStrength
        )
        self.gestureEngine = GestureEngine(
            dwellRadiusPx: s.dwellRadiusPx,
            dwellDurationMs: s.dwellDurationMs,
            dwellCooldownMs: s.dwellCooldownMs,
            rearmDistancePx: s.dwellRearmDistancePx,
            isDwellEnabled: s.dwellClickEnabled,
            isBlinkEnabled: s.blinkClickEnabled,
            isNodEnabled: s.nodGestureEnabled,
            isJawDropEnabled: s.jawDropClickEnabled,
            jawDropThreshold: s.jawDropRatioThreshold
        )

        self.camera = CameraManager()
        self.landmarkProcessor = FaceLandmarkProcessor()
        self.headphoneTracker = HeadphoneVisualTracker()
        self.headphoneDetector = HeadphoneTapDetector()
        self.headphoneMonitor = HeadphoneConnectionMonitor()

        self.isPrivacyShutterActive = s.privacyHideCameraPreview
        self.isTrackingActive = true // Start active out-of-the-box

        setupPipeline()
        setupHotkeys()

        camera.start()

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if !self.permissions.isCameraAuthorized {
                _ = await self.permissions.requestCameraPermission()
            }
            if !self.permissions.isAccessibilityAuthorized {
                self.permissions.promptAccessibilityPermission()
            }
        }
    }

    private func setupPipeline() {
        gestureEngine.onClick = { [weak self] pos, isRight in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.settingsStore.settings.dragAndDropMode && !isRight {
                    if self.cursorController.isDragging {
                        self.cursorController.endDrag(at: pos == .zero ? nil : pos)
                        self.isDragging = false
                    } else {
                        self.cursorController.startDrag(at: pos == .zero ? nil : pos)
                        self.isDragging = true
                    }
                } else {
                    self.cursorController.click(isRightClick: isRight, at: pos == .zero ? nil : pos)
                }

                if self.settingsStore.settings.audioFeedbackEnabled {
                    NSSound(named: "Tink")?.play()
                }
            }
        }

        gestureEngine.onJawDrop = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.settingsStore.settings.dragAndDropMode {
                    if self.cursorController.isDragging {
                        self.cursorController.endDrag()
                        self.isDragging = false
                    } else {
                        self.cursorController.startDrag()
                        self.isDragging = true
                    }
                } else {
                    self.cursorController.click(isRightClick: false)
                }

                if self.settingsStore.settings.audioFeedbackEnabled {
                    NSSound(named: "Pop")?.play()
                }
            }
        }

        headphoneDetector.onSingleTap = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isTrackingActive else { return }
                self.cursorController.click(isRightClick: false)
                if self.settingsStore.settings.audioFeedbackEnabled {
                    NSSound(named: "Tink")?.play()
                }
            }
        }

        headphoneDetector.onDoubleTap = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isTrackingActive else { return }
                self.cursorController.click(isRightClick: true)
                if self.settingsStore.settings.audioFeedbackEnabled {
                    NSSound(named: "Pop")?.play()
                }
            }
        }

        camera.onFrameCaptured = { [weak self] pixelBuffer, timestamp in
            guard let self = self else { return }
            let t0 = ProcessInfo.processInfo.systemUptime
            let headphoneFrame = self.headphoneTracker.processPixelBuffer(pixelBuffer, timestamp: timestamp)
            let dt = (ProcessInfo.processInfo.systemUptime - t0) * 1000.0

            let wrapped = SendableBuffer(buffer: pixelBuffer)
            Task { @MainActor [weak self] in
                self?.handleHeadphoneFrame(headphoneFrame, pixelBuffer: wrapped.buffer, latency: dt)
            }
        }

        _ = camera.setupSession()
    }

    private func handleHeadphoneFrame(_ frame: ProcessedHeadphoneFrame, pixelBuffer: CVPixelBuffer, latency: Double) {
        self.latestPixelBuffer = pixelBuffer
        self.latencyMs = 0.9 * self.latencyMs + 0.1 * latency

        let now = frame.timestamp
        if lastFrameTime > 0 {
            let instantFps = 1.0 / max(0.001, now - lastFrameTime)
            self.fps = 0.9 * self.fps + 0.1 * instantFps
        }
        lastFrameTime = now

        guard frame.isDetected else {
            // Headphone lost or out of view: freeze cursor safely
            self.isFaceLocked = false
            self.isHeadphoneLocked = false
            self.statusMessage = "Headphone Out of View — Cursor Paused"
            self.dwellProgress = 0.0
            self.gestureEngine.dwellDetector.cancel()
            return
        }

        self.isFaceLocked = true
        self.isHeadphoneLocked = true
        self.headphoneNormalizedPos = CGPoint(x: frame.normalizedX, y: frame.normalizedY)
        self.headphoneBoundingBox = frame.boundingBox
        self.trackingModeName = frame.trackingMode

        // Auto-initialize neutral baseline on first acquisition
        if !hasInitializedBaseline {
            movementEngine.setHeadphoneBaseline(normX: frame.normalizedX, normY: frame.normalizedY)
            hasInitializedBaseline = true
        }

        // Calibration handling
        if isCalibrating {
            movementEngine.setHeadphoneBaseline(normX: frame.normalizedX, normY: frame.normalizedY)
            self.isCalibrating = false
            self.statusMessage = "Headphone Centered"
            return
        }

        guard isTrackingActive else {
            self.statusMessage = "Tracking Paused"
            return
        }

        self.statusMessage = "Tracking Active (\(frame.trackingMode))"

        let currentPos = cursorController.getCurrentPosition()
        movementEngine.gravityDamping = gravityEngine.evaluateDamping(at: currentPos, velocity: 50.0, timestamp: now)

        let targetPos = movementEngine.processHeadphone(
            normX: frame.normalizedX,
            normY: frame.normalizedY,
            timestamp: now
        )

        cursorController.moveTo(targetPos, timestamp: now)
        self.filterCutoffHz = movementEngine.currentFilterCutoff

        // Process dwell clicks at target position
        let (dState, dProg) = gestureEngine.update(
            cursorPos: targetPos,
            deltaYawDeg: 0,
            deltaPitchDeg: 0,
            leftEAR: 0.3,
            rightEAR: 0.3,
            mouthRatio: 0.0,
            timestamp: now,
            isFaceLocked: true
        )
        self.dwellState = dState
        self.dwellProgress = dProg
    }

    public func startTracking() {
        if !camera.isRunning {
            camera.start()
        }
        isTrackingActive = true
    }

    public func pauseTracking() {
        isTrackingActive = false
        gestureEngine.dwellDetector.cancel()
    }

    public func toggleTracking() {
        if isTrackingActive {
            pauseTracking()
        } else {
            startTracking()
        }
    }

    public func startCalibration() {
        if isHeadphoneLocked {
            movementEngine.setHeadphoneBaseline(normX: headphoneNormalizedPos.x, normY: headphoneNormalizedPos.y)
            statusMessage = "Headphone Center Reset"
            if settingsStore.settings.audioFeedbackEnabled {
                NSSound(named: "Pop")?.play()
            }
        } else {
            isCalibrating = true
            calibrationProgress = 0.0
            statusMessage = "Hold Headphone in Center..."
        }
    }

    public func cancelCalibration() {
        isCalibrating = false
        calibrationManager.cancel()
    }

    public func emergencyStop() {
        pauseTracking()
        camera.stop()
        gestureEngine.dwellDetector.cancel()
        headphoneDetector.cleanup()
        statusMessage = "Emergency Stopped"
    }

    private func setupHotkeys() {
        // Global monitor for Cmd + Shift + Space
        hotKeyBox.monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 { // 49 is Spacebar
                Task { @MainActor in
                    self.toggleTracking()
                }
            }
        }
    }

    deinit {
        if let monitor = hotKeyBox.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
