import XCTest
@testable import HeadMotionMouseCore

final class MovementEngineTests: XCTestCase {
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

    private func getRepoRoot() -> URL {
        let currentFileURL = URL(fileURLWithPath: #file)
        return currentFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDeadZoneAgainstGoldenVectors() throws {
        let jsonURL = getRepoRoot().appendingPathComponent("shared/test-vectors/dead_zone.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenDeadZone.self, from: data)

        for c in golden.cases {
            let res = DeadZoneProcessor.apply(value: c.input, threshold: golden.threshold, epsilon: golden.epsilon)
            XCTAssertEqual(res, c.expected, accuracy: 1e-6, "Dead zone mismatch for \(c.input)")
        }
    }

    func testMovementMapperRollProjection() throws {
        let jsonURL = getRepoRoot().appendingPathComponent("shared/test-vectors/movement_mapper.json")
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
            XCTAssertEqual(resPsi, c.expected_psi_proj, accuracy: 1e-6)
            XCTAssertEqual(resTheta, c.expected_theta_proj, accuracy: 1e-6)
        }
    }

    func testScreenBoundsClamping() {
        let engine = MovementEngine(
            screenWidth: 1920.0,
            screenHeight: 1080.0,
            mappingMode: .directAbsolute
        )
        engine.setBaseline(yaw: 0.0, pitch: 0.0, roll: 0.0)

        let ptMax = engine.process(rawYaw: 100.0, rawPitch: 100.0, rawRoll: 0.0, timestamp: 1.0)
        XCTAssertGreaterThanOrEqual(ptMax.x, 0.0)
        XCTAssertLessThanOrEqual(ptMax.x, 1920.0)
        XCTAssertGreaterThanOrEqual(ptMax.y, 0.0)
        XCTAssertLessThanOrEqual(ptMax.y, 1080.0)

        let ptMin = engine.process(rawYaw: -100.0, rawPitch: -100.0, rawRoll: 0.0, timestamp: 2.0)
        XCTAssertGreaterThanOrEqual(ptMin.x, 0.0)
        XCTAssertLessThanOrEqual(ptMin.x, 1920.0)
        XCTAssertGreaterThanOrEqual(ptMin.y, 0.0)
        XCTAssertLessThanOrEqual(ptMin.y, 1080.0)
    }
}
