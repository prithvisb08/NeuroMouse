import Foundation
import SwiftUI

/// Settings configuration model matching shared/default-settings.json
public struct AppSettings: Codable, Sendable {
    public var schemaVersion: Int
    public var cameraIndex: Int
    public var cameraWidth: Int
    public var cameraHeight: Int
    public var targetFps: Int
    public var mappingMode: String
    public var horizontalSensitivity: Double
    public var verticalSensitivity: Double
    public var yawRangeDeg: Double
    public var pitchRangeDeg: Double
    public var horizontalDeadZoneDeg: Double
    public var verticalDeadZoneDeg: Double
    public var oneEuroMinCutoff: Double
    public var oneEuroBeta: Double
    public var oneEuroDCutoff: Double
    public var parallaxCompensation: Double
    public var invertHorizontal: Bool
    public var invertVertical: Bool
    public var uiGravityEnabled: Bool
    public var uiGravityStrength: Double
    public var dwellClickEnabled: Bool
    public var dwellDurationMs: Double
    public var dwellRadiusPx: Double
    public var dwellCooldownMs: Double
    public var dwellRearmDistancePx: Double
    public var blinkClickEnabled: Bool
    public var blinkMinDurationMs: Double
    public var blinkMaxDurationMs: Double
    public var doubleBlinkRightClick: Bool
    public var nodGestureEnabled: Bool
    public var scrollEnabled: Bool
    public var scrollSpeed: Double
    public var confidenceThreshold: Double
    public var reentryStableFrames: Int
    public var physicalMouseOverridePause: Bool
    public var physicalOverrideThresholdPx: Double
    public var faceLossFreeze: Bool
    public var privacyHideCameraPreview: Bool
    public var startPaused: Bool
    public var audioFeedbackEnabled: Bool
    public var smoothingPreset: String
    public var dragAndDropMode: Bool
    public var jawDropClickEnabled: Bool
    public var jawDropRatioThreshold: Double
    public var headPitchScrollMode: Bool
    public var jblHeadphoneClicksEnabled: Bool
    public var pitchScrollSensitivity: Double
    public var pitchScrollDeadZoneDeg: Double

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case cameraIndex = "camera_index"
        case cameraWidth = "camera_width"
        case cameraHeight = "camera_height"
        case targetFps = "target_fps"
        case mappingMode = "mapping_mode"
        case horizontalSensitivity = "horizontal_sensitivity"
        case verticalSensitivity = "vertical_sensitivity"
        case yawRangeDeg = "yaw_range_deg"
        case pitchRangeDeg = "pitch_range_deg"
        case horizontalDeadZoneDeg = "horizontal_dead_zone_deg"
        case verticalDeadZoneDeg = "vertical_dead_zone_deg"
        case oneEuroMinCutoff = "one_euro_min_cutoff"
        case oneEuroBeta = "one_euro_beta"
        case oneEuroDCutoff = "one_euro_d_cutoff"
        case parallaxCompensation = "parallax_compensation"
        case invertHorizontal = "invert_horizontal"
        case invertVertical = "invert_vertical"
        case uiGravityEnabled = "ui_gravity_enabled"
        case uiGravityStrength = "ui_gravity_strength"
        case dwellClickEnabled = "dwell_click_enabled"
        case dwellDurationMs = "dwell_duration_ms"
        case dwellRadiusPx = "dwell_radius_px"
        case dwellCooldownMs = "dwell_cooldown_ms"
        case dwellRearmDistancePx = "dwell_rearm_distance_px"
        case blinkClickEnabled = "blink_click_enabled"
        case blinkMinDurationMs = "blink_min_duration_ms"
        case blinkMaxDurationMs = "blink_max_duration_ms"
        case doubleBlinkRightClick = "double_blink_right_click"
        case nodGestureEnabled = "nod_gesture_enabled"
        case scrollEnabled = "scroll_enabled"
        case scrollSpeed = "scroll_speed"
        case confidenceThreshold = "confidence_threshold"
        case reentryStableFrames = "reentry_stable_frames"
        case physicalMouseOverridePause = "physical_mouse_override_pause"
        case physicalOverrideThresholdPx = "physical_override_threshold_px"
        case faceLossFreeze = "face_loss_freeze"
        case privacyHideCameraPreview = "privacy_hide_camera_preview"
        case startPaused = "start_paused"
        case audioFeedbackEnabled = "audio_feedback_enabled"
        case smoothingPreset = "smoothing_preset"
        case dragAndDropMode = "drag_and_drop_mode"
        case jawDropClickEnabled = "jaw_drop_click_enabled"
        case jawDropRatioThreshold = "jaw_drop_ratio_threshold"
        case headPitchScrollMode = "head_pitch_scroll_mode"
        case jblHeadphoneClicksEnabled = "jbl_headphone_clicks_enabled"
        case pitchScrollSensitivity = "pitch_scroll_sensitivity"
        case pitchScrollDeadZoneDeg = "pitch_scroll_dead_zone_deg"
    }

    public static let `default` = AppSettings(
        schemaVersion: 2,
        cameraIndex: 0,
        cameraWidth: 640,
        cameraHeight: 480,
        targetFps: 30,
        mappingMode: "hybrid_absolute",
        horizontalSensitivity: 1.0,
        verticalSensitivity: 1.0,
        yawRangeDeg: 15.0,
        pitchRangeDeg: 10.0,
        horizontalDeadZoneDeg: 1.2,
        verticalDeadZoneDeg: 1.2,
        oneEuroMinCutoff: 1.0,
        oneEuroBeta: 0.04,
        oneEuroDCutoff: 1.0,
        parallaxCompensation: 0.65,
        invertHorizontal: false,
        invertVertical: false,
        uiGravityEnabled: true,
        uiGravityStrength: 0.45,
        dwellClickEnabled: true,
        dwellDurationMs: 800.0,
        dwellRadiusPx: 18.0,
        dwellCooldownMs: 1000.0,
        dwellRearmDistancePx: 25.0,
        blinkClickEnabled: false,
        blinkMinDurationMs: 280.0,
        blinkMaxDurationMs: 650.0,
        doubleBlinkRightClick: true,
        nodGestureEnabled: false,
        scrollEnabled: false,
        scrollSpeed: 1.0,
        confidenceThreshold: 0.65,
        reentryStableFrames: 10,
        physicalMouseOverridePause: true,
        physicalOverrideThresholdPx: 40.0,
        faceLossFreeze: true,
        privacyHideCameraPreview: false,
        startPaused: true,
        audioFeedbackEnabled: true,
        smoothingPreset: "balanced",
        dragAndDropMode: false,
        jawDropClickEnabled: false,
        jawDropRatioThreshold: 0.18,
        headPitchScrollMode: true,
        jblHeadphoneClicksEnabled: true,
        pitchScrollSensitivity: 1.0,
        pitchScrollDeadZoneDeg: 1.8
    )
}

public enum SmoothingPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case balanced = "balanced"
    case precision = "precision"
    case responsive = "responsive"
    case highTremor = "high_tremor"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .balanced: return "Balanced (General Use)"
        case .precision: return "Precision / CAD (Ultra-Steady)"
        case .responsive: return "Responsive / Fast Travel"
        case .highTremor: return "Accessibility (High-Tremor Filter)"
        }
    }
}

@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var settings: AppSettings

    private let fileURL: URL

    public init(customFileURL: URL? = nil) {
        if let custom = customFileURL {
            self.fileURL = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = appSupport.appendingPathComponent("HeadMotionMouse", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("settings.json")
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                let decoder = JSONDecoder()
                self.settings = try decoder.decode(AppSettings.self, from: data)
            } catch {
                self.settings = .default
                self.save()
            }
        } else {
            self.settings = .default
            self.save()
        }
    }

    public func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[ERROR] Failed to save settings: \(error)")
        }
    }

    public func resetToDefaults() {
        self.settings = .default
        save()
    }

    public func applySmoothingPreset(_ preset: SmoothingPreset) {
        settings.smoothingPreset = preset.rawValue
        switch preset {
        case .balanced:
            settings.oneEuroMinCutoff = 1.0
            settings.oneEuroBeta = 0.04
            settings.horizontalDeadZoneDeg = 1.2
            settings.verticalDeadZoneDeg = 1.2
        case .precision:
            settings.oneEuroMinCutoff = 0.4
            settings.oneEuroBeta = 0.015
            settings.horizontalDeadZoneDeg = 1.8
            settings.verticalDeadZoneDeg = 1.8
        case .responsive:
            settings.oneEuroMinCutoff = 1.8
            settings.oneEuroBeta = 0.08
            settings.horizontalDeadZoneDeg = 0.8
            settings.verticalDeadZoneDeg = 0.8
        case .highTremor:
            settings.oneEuroMinCutoff = 0.3
            settings.oneEuroBeta = 0.005
            settings.horizontalDeadZoneDeg = 2.5
            settings.verticalDeadZoneDeg = 2.5
        }
        save()
    }
}
