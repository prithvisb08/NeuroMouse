import XCTest
@testable import HeadMotionMouseCore

final class OneEuroFilterTests: XCTestCase {
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

    func testOneEuroFilterAgainstGoldenVectors() throws {
        // Resolve path to shared/test-vectors/one_euro.json
        let currentFileURL = URL(fileURLWithPath: #file)
        let repoRoot = currentFileURL
            .deletingLastPathComponent() // HeadMotionMouseTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // macos-app
            .deletingLastPathComponent() // repo root
        let jsonURL = repoRoot.appendingPathComponent("shared/test-vectors/one_euro.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.path), "Missing \(jsonURL.path)")

        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        let golden = try decoder.decode(GoldenOneEuro.self, from: data)

        let filter = OneEuroFilter(
            minCutoff: golden.min_cutoff,
            beta: golden.beta,
            dCutoff: golden.d_cutoff
        )

        for c in golden.cases {
            let res = filter.filter(x: c.input, timestamp: c.t)
            XCTAssertEqual(res, c.expected, accuracy: 1e-5, "Mismatch at t=\(c.t)")
        }
    }

    func testFilterReset() {
        let filter = OneEuroFilter()
        XCTAssertEqual(filter.filter(x: 10.0, timestamp: 0.0), 10.0)
        XCTAssertLessThan(filter.filter(x: 20.0, timestamp: 0.033), 20.0)
        filter.reset()
        XCTAssertEqual(filter.filter(x: 50.0, timestamp: 1.0), 50.0)
    }
}
