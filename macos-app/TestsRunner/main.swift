import Foundation
import CoreGraphics
import HeadMotionMouseCore

struct GoldenCase: Decodable {
    let t: Double
    let input: Double
    let expected: Double
}

struct GoldenOneEuro: Decodable {
    let min_cutoff: Double
    let beta: Double
    let d_cutoff: Double
    let cases: [GoldenCase]
}

struct DeadZoneCase: Decodable {
    let input: Double
    let expected: Double
}

struct GoldenDeadZone: Decodable {
    let threshold: Double
    let epsilon: Double
    let cases: [DeadZoneCase]
}

struct MovementMapperCase: Decodable {
    let delta_psi: Double
    let delta_theta: Double
    let expected_psi_proj: Double
    let expected_theta_proj: Double
}

struct GoldenMovementMapper: Decodable {
    let calibrated_roll_deg: Double
    let screen_width: Double
    let screen_height: Double
    let yaw_range_deg: Double
    let pitch_range_deg: Double
    let cases: [MovementMapperCase]
}

struct GoldenCalibration: Decodable {
    let samples: [Double]
    let median: Double
    let mad: Double
    let inlier_count: Int
    let trimmed_mean: Double
    let outliers: [Double]
}

struct ParallaxCase: Decodable {
    let psi: Double
    let theta: Double
    let Tx: Double
    let Ty: Double
    let Tz: Double
    let expected_psi_corr: Double
    let expected_theta_corr: Double
}

struct GoldenParallax: Decodable {
    let k_parallax: Double
    let cases: [ParallaxCase]
}

func getRepoRoot() -> URL {
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    if cwd.lastPathComponent == "macos-app" {
        return cwd.deletingLastPathComponent()
    }
    return cwd
}

final class TestBox: @unchecked Sendable {
    var count: Int = 0
}

@MainActor
func main() {
    var passedCount = 0
    var failedCount = 0

    func runTest(_ name: String, block: () throws -> Void) {
        do {
            try block()
            passedCount += 1
            print("  ✓ \(name) PASSED")
        } catch {
            failedCount += 1
            print("  ✗ \(name) FAILED: \(error)")
        }
    }

    print("==========================================================")
    print("  HeadMotion Mouse — Native Swift Test Suite")
    print("==========================================================")

    let root = getRepoRoot()

    // 1. One Euro Filter Tests
    runTest("OneEuroFilter against shared golden vectors") {
        let jsonURL = root.appendingPathComponent("shared/test-vectors/one_euro.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenOneEuro.self, from: data)

        let filter = OneEuroFilter(minCutoff: golden.min_cutoff, beta: golden.beta, dCutoff: golden.d_cutoff)
        for c in golden.cases {
            let res = filter.filter(x: c.input, timestamp: c.t)
            assert(abs(res - c.expected) < 1e-5, "Mismatch at t=\(c.t): expected \(c.expected), got \(res)")
        }
    }

    runTest("OneEuroFilter reset handling") {
        let filter = OneEuroFilter()
        assert(filter.filter(x: 10.0, timestamp: 0.0) == 10.0)
        assert(filter.filter(x: 20.0, timestamp: 0.033) < 20.0)
        filter.reset()
        assert(filter.filter(x: 50.0, timestamp: 1.0) == 50.0)
    }

    // 2. Dead Zone Tests
    runTest("DeadZone against shared golden vectors") {
        let jsonURL = root.appendingPathComponent("shared/test-vectors/dead_zone.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenDeadZone.self, from: data)

        for c in golden.cases {
            let res = DeadZoneProcessor.apply(value: c.input, threshold: golden.threshold, epsilon: golden.epsilon)
            assert(abs(res - c.expected) < 1e-6, "Dead zone mismatch for \(c.input): expected \(c.expected), got \(res)")
        }
    }

    // 3. Movement Mapper Roll Projection
    runTest("MovementMapper roll-horizon projection") {
        let jsonURL = root.appendingPathComponent("shared/test-vectors/movement_mapper.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenMovementMapper.self, from: data)

        let engine = MovementEngine(
            screenWidth: golden.screen_width,
            screenHeight: golden.screen_height,
            yawRangeDeg: golden.yaw_range_deg,
            pitchRangeDeg: golden.pitch_range_deg
        )

        for c in golden.cases {
            let (resPsi, resTheta) = engine.projectRollHorizon(
                deltaYaw: c.delta_psi,
                deltaPitch: c.delta_theta,
                baselineRollDeg: golden.calibrated_roll_deg
            )
            assert(abs(resPsi - c.expected_psi_proj) < 1e-6)
            assert(abs(resTheta - c.expected_theta_proj) < 1e-6)
        }
    }

    runTest("MovementMapper screen bounds clamping") {
        let engine = MovementEngine(screenWidth: 1920.0, screenHeight: 1080.0, mappingMode: .directAbsolute)
        engine.setBaseline(yaw: 0.0, pitch: 0.0, roll: 0.0)

        let ptMax = engine.process(rawYaw: 100.0, rawPitch: 100.0, rawRoll: 0.0, timestamp: 1.0)
        assert(ptMax.x >= 0.0 && ptMax.x <= 1920.0)
        assert(ptMax.y >= 0.0 && ptMax.y <= 1080.0)

        let ptMin = engine.process(rawYaw: -100.0, rawPitch: -100.0, rawRoll: 0.0, timestamp: 2.0)
        assert(ptMin.x >= 0.0 && ptMin.x <= 1920.0)
        assert(ptMin.y >= 0.0 && ptMin.y <= 1080.0)
    }

    // 4. Calibration Tests
    runTest("Calibration against shared golden vectors") {
        let jsonURL = root.appendingPathComponent("shared/test-vectors/calibration.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenCalibration.self, from: data)

        let (inliers, meanVal, _) = CalibrationManager.computeMADInliers(samples: golden.samples)
        assert(inliers.count == golden.inlier_count)
        assert(abs(meanVal - golden.trimmed_mean) < 1e-6)

        for outl in golden.outliers {
            assert(!inliers.contains(outl))
        }
    }

    runTest("Calibration excessive motion rejection") {
        let manager = CalibrationManager(durationSec: 2.0, minFrames: 10, maxStdDeg: 1.8)
        manager.start(currentTime: 0.0)

        let spreadSamples: [Double] = [-4.0, -3.5, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 3.5, 4.0, -2.5, 2.5]
        for (i, yaw) in spreadSamples.enumerated() {
            _ = manager.addSample(yaw: yaw, pitch: 0.0, roll: 0.0, timestamp: Double(i) * 0.1)
        }

        let result = manager.finalize()
        assert(!result.success)
        assert(result.errorMessage?.contains("Excessive motion") ?? false)
    }

    // 5. Parallax Compensation Tests
    runTest("Parallax compensation against shared golden vectors") {
        let jsonURL = root.appendingPathComponent("shared/test-vectors/parallax.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenParallax.self, from: data)

        let engine = MovementEngine(kParallax: golden.k_parallax)
        for c in golden.cases {
            let (resPsi, resTheta) = engine.applyParallaxCompensation(yaw: c.psi, pitch: c.theta, tx: c.Tx, ty: c.Ty, tz: c.Tz)
            assert(abs(resPsi - c.expected_psi_corr) < 1e-6)
            assert(abs(resTheta - c.expected_theta_corr) < 1e-6)
        }
    }

    runTest("Lean-only translation invariance regression") {
        let engine = MovementEngine(screenWidth: 1920.0, screenHeight: 1080.0, mappingMode: .directAbsolute)
        engine.setBaseline(yaw: 0.0, pitch: 0.0, roll: 0.0)

        let p0 = engine.process(rawYaw: 0.0, rawPitch: 0.0, rawRoll: 0.0, timestamp: 0.0, tx: 0.0, ty: 0.0, tz: 500.0, isHybridPose: false)

        for step in 1...10 {
            let txLean = Double(step) * 12.0
            let tNow = Double(step) * 0.0333

            let pCurr = engine.process(rawYaw: 0.0, rawPitch: 0.0, rawRoll: 0.0, timestamp: tNow, tx: txLean, ty: 0.0, tz: 500.0, isHybridPose: false)
            let delta = hypot(pCurr.x - p0.x, pCurr.y - p0.y)
            assert(delta < 1e-4, "False cursor drift: \(delta) px")
        }
    }

    // 6. Gestures Tests
    runTest("DwellClick state machine lifecycle") {
        let box = TestBox()
        let detector = DwellClickDetector(dwellRadiusPx: 18.0, dwellDurationMs: 800.0, dwellCooldownMs: 1000.0, rearmDistancePx: 25.0) { _, _ in
            box.count += 1
        }

        let (s1, p1) = detector.update(cursorPos: CGPoint(x: 100, y: 100), timestamp: 0.0)
        assert(s1 == .dwelling && p1 == 0.0)

        let (s2, p2) = detector.update(cursorPos: CGPoint(x: 105, y: 104), timestamp: 0.4)
        assert(s2 == .dwelling && p2 >= 0.4)

        let (s3, p3) = detector.update(cursorPos: CGPoint(x: 106, y: 102), timestamp: 0.81)
        assert(s3 == .triggered && p3 == 1.0)
        assert(box.count == 1)

        let (s4, _) = detector.update(cursorPos: CGPoint(x: 106, y: 102), timestamp: 0.85)
        assert(s4 == .cooldown)

        let (s5, _) = detector.update(cursorPos: CGPoint(x: 105, y: 102), timestamp: 1.9)
        assert(s5 == .idle)

        let (s6, _) = detector.update(cursorPos: CGPoint(x: 140, y: 100), timestamp: 2.0)
        assert(s6 == .dwelling)
    }

    runTest("BlinkDetector temporal classification") {
        let box = TestBox()
        let detector = BlinkDetector(earThreshold: 0.20, minDurationMs: 280.0, maxDurationMs: 650.0) { isRight in
            box.count += 1
        }

        // Involuntary 150ms blink -> ignored
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 0.0)
        _ = detector.update(leftEAR: 0.1, rightEAR: 0.1, timestamp: 0.1)
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 0.25)
        assert(box.count == 0)

        // Deliberate 400ms blink -> registered
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 1.0)
        _ = detector.update(leftEAR: 0.1, rightEAR: 0.1, timestamp: 1.1)
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 1.5)
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 2.0)
        assert(box.count == 1)
    }

    runTest("NodDetector impulse detection") {
        let box = TestBox()
        let detector = NodDetector(pitchThresholdDeg: 4.5, maxDurationSec: 0.45) {
            box.count += 1
        }

        _ = detector.update(deltaYawDeg: 0.0, deltaPitchDeg: 0.0, timestamp: 0.0)
        _ = detector.update(deltaYawDeg: 0.5, deltaPitchDeg: 5.2, timestamp: 0.15)
        let fired = detector.update(deltaYawDeg: 0.2, deltaPitchDeg: 1.0, timestamp: 0.30)
        assert(fired && box.count == 1)
    }

    runTest("DragAndDrop cursor state machine") {
        let controller = CursorController(physicalOverridePause: false)
        assert(!controller.isDragging)
        controller.startDrag(at: CGPoint(x: 200, y: 200))
        assert(controller.isDragging)
        let moved = controller.moveTo(CGPoint(x: 250, y: 250), timestamp: 1.0)
        assert(moved && controller.isDragging)
        controller.endDrag(at: CGPoint(x: 250, y: 250))
        assert(!controller.isDragging)
    }

    runTest("SmoothingPresets parameter configuration") {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let store = SettingsStore(customFileURL: tempURL)
        store.applySmoothingPreset(.precision)
        assert(store.settings.oneEuroMinCutoff == 0.4)
        assert(store.settings.oneEuroBeta == 0.015)
        assert(store.settings.horizontalDeadZoneDeg == 1.8)

        store.applySmoothingPreset(.responsive)
        assert(store.settings.oneEuroMinCutoff == 1.8)
        assert(store.settings.oneEuroBeta == 0.08)
        assert(store.settings.horizontalDeadZoneDeg == 0.8)

        try? FileManager.default.removeItem(at: tempURL)
    }

    runTest("JawDrop gesture detection and hysteresis reset") {
        let box = TestBox()
        let engine = GestureEngine(
            isDwellEnabled: false,
            isBlinkEnabled: false,
            isNodEnabled: false,
            isJawDropEnabled: true,
            jawDropThreshold: 0.18
        )
        engine.onJawDrop = {
            box.count += 1
        }

        // Mouth closed
        _ = engine.update(cursorPos: .zero, deltaYawDeg: 0, deltaPitchDeg: 0, leftEAR: 0.3, rightEAR: 0.3, mouthRatio: 0.05, timestamp: 1.0, isFaceLocked: true)
        assert(box.count == 0)

        // Mouth opened (jaw drop) sustained for > 180ms
        _ = engine.update(cursorPos: .zero, deltaYawDeg: 0, deltaPitchDeg: 0, leftEAR: 0.3, rightEAR: 0.3, mouthRatio: 0.22, timestamp: 1.1, isFaceLocked: true)
        _ = engine.update(cursorPos: .zero, deltaYawDeg: 0, deltaPitchDeg: 0, leftEAR: 0.3, rightEAR: 0.3, mouthRatio: 0.24, timestamp: 1.30, isFaceLocked: true)
        assert(box.count == 1)

        // Mouth closed again resets hysteresis
        _ = engine.update(cursorPos: .zero, deltaYawDeg: 0, deltaPitchDeg: 0, leftEAR: 0.3, rightEAR: 0.3, mouthRatio: 0.04, timestamp: 1.5, isFaceLocked: true)
        assert(box.count == 1)
    }

    runTest("HeadphoneTapDetector initialization and cleanup") {
        let detector = HeadphoneTapDetector()
        detector.isEnabled = true
        detector.cleanup()
    }

    print("==========================================================")
    print("  Total Tests: \(passedCount + failedCount) | Passed: \(passedCount) | Failed: \(failedCount)")
    print("==========================================================")

    if failedCount > 0 {
        exit(1)
    }
}

main()
