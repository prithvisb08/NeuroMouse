import SwiftUI

public struct SettingsTabView: View {
    @ObservedObject var settingsStore: SettingsStore

    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    public var body: some View {
        TabView {
            motionTab
                .tabItem {
                    Label("Motion & Speed", systemImage: "cursorarrow.motionlines")
                }

            gesturesTab
                .tabItem {
                    Label("Gestures & Clicking", systemImage: "hand.tap")
                }

            safetyTab
                .tabItem {
                    Label("Safety & Hardware", systemImage: "shield.checkerboard")
                }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 400)
    }

    private var motionTab: some View {
        Form {
            Section("Smoothing Profile Presets") {
                Picker("Preset Profile", selection: Binding(
                    get: { SmoothingPreset(rawValue: settingsStore.settings.smoothingPreset) ?? .balanced },
                    set: { newPreset in
                        settingsStore.applySmoothingPreset(newPreset)
                    }
                )) {
                    ForEach(SmoothingPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Tracking Sensitivity") {
                Slider(value: $settingsStore.settings.horizontalSensitivity, in: 0.2...3.0, step: 0.1) {
                    Text("Horizontal Sensitivity: \(settingsStore.settings.horizontalSensitivity, specifier: "%.1f")x")
                }
                Slider(value: $settingsStore.settings.verticalSensitivity, in: 0.2...3.0, step: 0.1) {
                    Text("Vertical Sensitivity: \(settingsStore.settings.verticalSensitivity, specifier: "%.1f")x")
                }
            }

            Section("Dead Zones & Smoothing (1€ Filter)") {
                Slider(value: $settingsStore.settings.horizontalDeadZoneDeg, in: 0.0...3.0, step: 0.1) {
                    Text("Horizontal Dead Zone: \(settingsStore.settings.horizontalDeadZoneDeg, specifier: "%.1f")°")
                }
                Slider(value: $settingsStore.settings.verticalDeadZoneDeg, in: 0.0...3.0, step: 0.1) {
                    Text("Vertical Dead Zone: \(settingsStore.settings.verticalDeadZoneDeg, specifier: "%.1f")°")
                }
                Slider(value: $settingsStore.settings.oneEuroMinCutoff, in: 0.1...3.0, step: 0.1) {
                    Text("1€ Min Cutoff (Jitter suppression): \(settingsStore.settings.oneEuroMinCutoff, specifier: "%.1f") Hz")
                }
                Slider(value: $settingsStore.settings.oneEuroBeta, in: 0.001...0.1, step: 0.005) {
                    Text("1€ Beta (Speed adaptation): \(settingsStore.settings.oneEuroBeta, specifier: "%.3f")")
                }
            }

            Section("Inversion & Mapping") {
                Toggle("Invert Horizontal Cursor Movement", isOn: $settingsStore.settings.invertHorizontal)
                Toggle("Invert Vertical Cursor Movement", isOn: $settingsStore.settings.invertVertical)
                Toggle("Target Magnetism (Accessibility UI Gravity)", isOn: $settingsStore.settings.uiGravityEnabled)
            }
        }
        .onChange(of: settingsStore.settings.horizontalSensitivity) { _, _ in settingsStore.save() }
        .onChange(of: settingsStore.settings.verticalSensitivity) { _, _ in settingsStore.save() }
        .onChange(of: settingsStore.settings.horizontalDeadZoneDeg) { _, _ in settingsStore.save() }
        .onChange(of: settingsStore.settings.verticalDeadZoneDeg) { _, _ in settingsStore.save() }
    }

    private var gesturesTab: some View {
        Form {
            Section("JBL Live 770NC Headphone Clicker") {
                Toggle("Enable JBL 770NC Headphone Taps", isOn: $settingsStore.settings.jblHeadphoneClicksEnabled)
                Text("Tap earcup once for Left Click; double-tap for Right Click.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Head Pitch Scrolling (Up / Down)") {
                Toggle("Head Pitch Controls Page Scroll", isOn: $settingsStore.settings.headPitchScrollMode)
                if settingsStore.settings.headPitchScrollMode {
                    Slider(value: $settingsStore.settings.pitchScrollSensitivity, in: 0.5...3.0, step: 0.1) {
                        Text("Scroll Speed: \(settingsStore.settings.pitchScrollSensitivity, specifier: "%.1f")x")
                    }
                    Slider(value: $settingsStore.settings.pitchScrollDeadZoneDeg, in: 0.5...4.0, step: 0.2) {
                        Text("Tilt Dead Zone: \(settingsStore.settings.pitchScrollDeadZoneDeg, specifier: "%.1f")°")
                    }
                }
            }

            Section("Dwell Clicking") {
                Toggle("Enable Dwell Click", isOn: $settingsStore.settings.dwellClickEnabled)
                Slider(value: $settingsStore.settings.dwellDurationMs, in: 400...2000, step: 50) {
                    Text("Dwell Hold Time: \(Int(settingsStore.settings.dwellDurationMs)) ms")
                }
                Slider(value: $settingsStore.settings.dwellRadiusPx, in: 10...35, step: 1) {
                    Text("Dwell Stability Radius: \(Int(settingsStore.settings.dwellRadiusPx)) px")
                }
            }

            Section("Blink & Nod Gestures") {
                Toggle("Enable Intentional Blink Clicking", isOn: $settingsStore.settings.blinkClickEnabled)
                Toggle("Double-Blink for Right Click", isOn: $settingsStore.settings.doubleBlinkRightClick)
                Toggle("Enable Head Nod Gesture", isOn: $settingsStore.settings.nodGestureEnabled)
            }

            Section("Drag & Drop Mode") {
                Toggle("Drag & Drop Mode (Alternate Clicks Lock / Release)", isOn: $settingsStore.settings.dragAndDropMode)
            }

            Section("Audio Feedback") {
                Toggle("Audible Click Confirmation (macOS Tink)", isOn: $settingsStore.settings.audioFeedbackEnabled)
            }

            Section("Facial Secondary Trigger (Speech Immune)") {
                Toggle("Jaw Drop / Mouth Open Trigger", isOn: $settingsStore.settings.jawDropClickEnabled)
                if settingsStore.settings.jawDropClickEnabled {
                    Slider(value: $settingsStore.settings.jawDropRatioThreshold, in: 0.12...0.30, step: 0.02) {
                        Text("Mouth Opening Ratio: \(settingsStore.settings.jawDropRatioThreshold, specifier: "%.2f")")
                    }
                }
            }
        }
        .onChange(of: settingsStore.settings.dwellDurationMs) { _, _ in settingsStore.save() }
        .onChange(of: settingsStore.settings.dwellClickEnabled) { _, _ in settingsStore.save() }
    }

    private var safetyTab: some View {
        Form {
            Section("Physical Mouse Override") {
                Toggle("Pause Head Tracking when Physical Mouse Moves", isOn: $settingsStore.settings.physicalMouseOverridePause)
                Slider(value: $settingsStore.settings.physicalOverrideThresholdPx, in: 20...100, step: 5) {
                    Text("Override Threshold: \(Int(settingsStore.settings.physicalOverrideThresholdPx)) px")
                }
            }

            Section("Face-Loss Freeze & Privacy") {
                Toggle("Instant Freeze when Face Leaves Frame", isOn: $settingsStore.settings.faceLossFreeze)
                Toggle("Mask Camera Preview (Privacy Shutter)", isOn: $settingsStore.settings.privacyHideCameraPreview)
            }
        }
    }
}
