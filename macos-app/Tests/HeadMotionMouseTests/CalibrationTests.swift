import XCTest
@testable import HeadMotionMouseCore

final class CalibrationTests: XCTestCase {
    struct GoldenCalibration: Decodable {
        let samples: [Double]
        let median: Double
        let mad: Double
        let inlier_count: Int
        let trimmed_mean: Double
        let outliers: [Double]
    }

    private func getRepoRoot() -> URL {
        let currentFileURL = URL(fileURLWithPath: #file)
        return currentFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testCalibrationAgainstGoldenVectors() throws {
        let jsonURL = getRepoRoot().appendingPathComponent("shared/test-vectors/calibration.json")
        let data = try Data(contentsOf: jsonURL)
        let golden = try JSONDecoder().decode(GoldenCalibration.self, from: data)

        let (inliers, meanVal, _) = CalibrationManager.computeMADInliers(samples: golden.samples)

        XCTAssertEqual(inliers.count, golden.inlier_count)
        XCTAssertEqual(meanVal, golden.trimmed_mean, accuracy: 1e-6)

        for outl in golden.outliers {
            XCTAssertFalse(inliers.contains(outl), "Outlier \(outl) was not rejected")
        }
    }

    func testExcessiveMovementRejection() {
        let manager = CalibrationManager(durationSec: 2.0, minFrames: 10, maxStdDeg: 1.8)
        manager.start(currentTime: 0.0)

        let spreadSamples: [Double] = [-4.0, -3.5, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 3.5, 4.0, -2.5, 2.5]
        for (i, yaw) in spreadSamples.enumerated() {
            _ = manager.addSample(yaw: yaw, pitch: 0.0, roll: 0.0, timestamp: Double(i) * 0.1)
        }

        let result = manager.finalize()
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errorMessage?.contains("Excessive motion") ?? false)
    }

    func testInsufficientFramesRejection() {
        let manager = CalibrationManager(durationSec: 2.0, minFrames: 45)
        manager.start(currentTime: 0.0)

        for i in 0..<10 {
            _ = manager.addSample(yaw: 0.0, pitch: 0.0, roll: 0.0, timestamp: Double(i) * 0.1)
        }

        let result = manager.finalize()
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errorMessage?.contains("Insufficient frames") ?? false)
    }
}
