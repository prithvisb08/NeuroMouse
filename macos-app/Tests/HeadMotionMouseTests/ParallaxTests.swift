import XCTest
@testable import HeadMotionMouseCore

final class ParallaxTests: XCTestCase {
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

    private func getRepoRoot() -> URL {
        let currentFileURL = URL(fileURLWithPath: #file)
        return currentFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testParallaxAgainstGoldenVectors() throws {
        let jsonURL = getRepoRoot().appendingPathComponent("shared/test-vectors/parallax.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenParallax.self, from: data)

        let engine = MovementEngine(kParallax: golden.k_parallax)

        for c in golden.cases {
            let (resPsi, resTheta) = engine.applyParallaxCompensation(
                yaw: c.psi,
                pitch: c.theta,
                tx: c.Tx,
                ty: c.Ty,
                tz: c.Tz
            )
            XCTAssertEqual(resPsi, c.expected_psi_corr, accuracy: 1e-6)
            XCTAssertEqual(resTheta, c.expected_theta_corr, accuracy: 1e-6)
        }
    }

    func testLeanOnlyTranslationInvarianceRegression() {
        let engine = MovementEngine(
            screenWidth: 1920.0,
            screenHeight: 1080.0,
            mappingMode: .directAbsolute
        )
        engine.setBaseline(yaw: 0.0, pitch: 0.0, roll: 0.0)

        let p0 = engine.process(
            rawYaw: 0.0,
            rawPitch: 0.0,
            rawRoll: 0.0,
            timestamp: 0.0,
            tx: 0.0,
            ty: 0.0,
            tz: 500.0,
            isHybridPose: false
        )

        for step in 1...10 {
            let txLean = Double(step) * 12.0
            let tNow = Double(step) * 0.0333

            let pCurr = engine.process(
                rawYaw: 0.0,
                rawPitch: 0.0,
                rawRoll: 0.0,
                timestamp: tNow,
                tx: txLean,
                ty: 0.0,
                tz: 500.0,
                isHybridPose: false
            )

            let delta = hypot(pCurr.x - p0.x, pCurr.y - p0.y)
            XCTAssertLessThan(delta, 1e-4, "False cursor drift during pure body lean: \(delta) px")
        }
    }
}
