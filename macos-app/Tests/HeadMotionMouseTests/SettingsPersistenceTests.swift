import XCTest
@testable import HeadMotionMouseCore

final class SettingsPersistenceTests: XCTestCase {
    func testSettingsStorePersistence() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_settings_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        await MainActor.run {
            let store = SettingsStore(customFileURL: tempURL)
            XCTAssertEqual(store.settings.schemaVersion, 2)
            XCTAssertEqual(store.settings.dwellDurationMs, 800.0)

            store.settings.dwellDurationMs = 950.0
            store.save()
        }

        // Reload from disk
        await MainActor.run {
            let reloadedStore = SettingsStore(customFileURL: tempURL)
            XCTAssertEqual(reloadedStore.settings.dwellDurationMs, 950.0)
        }
    }

    func testCorruptFileRecovery() async {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("corrupt_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Write corrupt garbage
        try? "INVALID_JSON_GARBAGE".data(using: .utf8)?.write(to: tempURL)

        await MainActor.run {
            let store = SettingsStore(customFileURL: tempURL)
            // Must gracefully recover to defaults
            XCTAssertEqual(store.settings.schemaVersion, 2)
            XCTAssertEqual(store.settings.dwellDurationMs, 800.0)
        }
    }
}
