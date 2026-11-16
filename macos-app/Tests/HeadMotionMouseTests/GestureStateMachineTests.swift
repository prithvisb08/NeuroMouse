import XCTest
@testable import HeadMotionMouseCore

final class GestureStateMachineTests: XCTestCase {
    func testDwellClickLifecycle() {
        var clickCount = 0
        let detector = DwellClickDetector(
            dwellRadiusPx: 18.0,
            dwellDurationMs: 800.0,
            dwellCooldownMs: 1000.0,
            rearmDistancePx: 25.0
        ) { _, _ in
            clickCount += 1
        }

        // 1. Initial position
        let (s1, p1) = detector.update(cursorPos: CGPoint(x: 100, y: 100), timestamp: 0.0)
        XCTAssertEqual(s1, .dwelling)
        XCTAssertEqual(p1, 0.0)

        // 2. Mid-dwell hold
        let (s2, p2) = detector.update(cursorPos: CGPoint(x: 105, y: 104), timestamp: 0.4)
        XCTAssertEqual(s2, .dwelling)
        XCTAssertGreaterThan(p2, 0.4)

        // 3. Trigger dwell click
        let (s3, p3) = detector.update(cursorPos: CGPoint(x: 106, y: 102), timestamp: 0.81)
        XCTAssertEqual(s3, .triggered)
        XCTAssertEqual(p3, 1.0)
        XCTAssertEqual(clickCount, 1)

        // 4. Cooldown
        let (s4, _) = detector.update(cursorPos: CGPoint(x: 106, y: 102), timestamp: 0.85)
        XCTAssertEqual(s4, .cooldown)

        // 5. Re-arm restriction
        let (s5, _) = detector.update(cursorPos: CGPoint(x: 105, y: 102), timestamp: 1.9)
        XCTAssertEqual(s5, .idle)

        // 6. Travel past 25px
        let (s6, _) = detector.update(cursorPos: CGPoint(x: 140, y: 100), timestamp: 2.0)
        XCTAssertEqual(s6, .dwelling)
    }

    func testBlinkDetectorClassification() {
        var registeredClicks: [Bool] = []
        let detector = BlinkDetector(
            earThreshold: 0.20,
            minDurationMs: 280.0,
            maxDurationMs: 650.0
        ) { isRight in
            registeredClicks.append(isRight)
        }

        // Involuntary 150ms blink -> ignored
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 0.0)
        _ = detector.update(leftEAR: 0.1, rightEAR: 0.1, timestamp: 0.1)
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 0.25)
        XCTAssertEqual(registeredClicks.count, 0)

        // Deliberate 400ms blink -> fires left click after window
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 1.0)
        _ = detector.update(leftEAR: 0.1, rightEAR: 0.1, timestamp: 1.1)
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 1.5)
        _ = detector.update(leftEAR: 0.3, rightEAR: 0.3, timestamp: 2.0)
        XCTAssertEqual(registeredClicks.count, 1)
        XCTAssertFalse(registeredClicks[0])
    }

    func testNodDetectorImpulse() {
        var nodCount = 0
        let detector = NodDetector(
            pitchThresholdDeg: 4.5,
            maxDurationSec: 0.45
        ) {
            nodCount += 1
        }

        _ = detector.update(deltaYawDeg: 0.0, deltaPitchDeg: 0.0, timestamp: 0.0)
        _ = detector.update(deltaYawDeg: 0.5, deltaPitchDeg: 5.2, timestamp: 0.15)
        let fired = detector.update(deltaYawDeg: 0.2, deltaPitchDeg: 1.0, timestamp: 0.30)

        XCTAssertTrue(fired)
        XCTAssertEqual(nodCount, 1)
    }
}
