import SwiftUI

public struct DashboardWindowView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header & Status Badges
            headerView
                .padding()
                .background(.ultraThinMaterial)

            if !appState.permissions.isAccessibilityAuthorized || !appState.permissions.isCameraAuthorized {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Action Required to Control Mouse")
                            .font(.headline)
                        Text(!appState.permissions.isAccessibilityAuthorized ?
                            "Enable Accessibility in macOS Settings. (If toggle is already ON, toggle it OFF then ON once to refresh macOS security cache)." :
                            "Enable Camera permission so HeadMotion can see headphone movements.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !appState.permissions.isAccessibilityAuthorized {
                        HStack(spacing: 8) {
                            Button("Reset Permission") {
                                appState.permissions.resetAccessibilityTCC()
                            }
                            .buttonStyle(.bordered)

                            Button("Open Settings") {
                                appState.permissions.promptAccessibilityPermission()
                                appState.permissions.openSystemAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }

                    if !appState.permissions.isCameraAuthorized {
                        Button("Open Camera Settings") {
                            Task {
                                _ = await appState.permissions.requestCameraPermission()
                                appState.permissions.openSystemCameraSettings()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.12))
            }

            Divider()

            // Main Content Area
            HStack(spacing: 16) {
                // Left: Camera Preview & Privacy Shutter
                VStack(alignment: .leading, spacing: 10) {
                    Text("Headphone Optical Sensor")
                        .font(.headline)
                    CameraPreviewView(appState: appState)
                }
                .frame(maxWidth: .infinity)

                // Right: Primary Controls & Diagnostics
                VStack(spacing: 12) {
                    controlsCard
                    jblGuideCard
                    diagnosticsCard
                }
                .frame(width: 300)
            }
            .padding()

            Divider()

            // Bottom Telemetry Bar
            telemetryBar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 520)
        .sheet(isPresented: $appState.showingCalibrationSheet) {
            CalibrationSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.showingSettingsSheet) {
            VStack {
                HStack {
                    Spacer()
                    Button("Done") { appState.showingSettingsSheet = false }
                        .padding()
                }
                SettingsTabView(settingsStore: appState.settingsStore)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "headphones")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Headphone Motion Mouse")
                    .font(.title3.bold())
                Text("Optical Headphone Motion & Wireless Clicker")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status Badges
            HStack(spacing: 8) {
                badge(
                    text: appState.permissions.isCameraAuthorized ? "Camera OK" : "Camera Denied",
                    icon: "camera.fill",
                    color: appState.permissions.isCameraAuthorized ? .green : .red
                )

                badge(
                    text: appState.permissions.isAccessibilityAuthorized ? "AX Granted" : "AX Required",
                    icon: "hand.raised.fill",
                    color: appState.permissions.isAccessibilityAuthorized ? .green : .orange
                )

                badge(
                    text: appState.headphoneMonitor.isConnected ?
                        (appState.headphoneMonitor.isJblModel ? "JBL 770NC Connected" : appState.headphoneMonitor.deviceName) :
                        "JBL Disconnected",
                    icon: appState.headphoneMonitor.isConnected ? "headphones" : "headphones.slash",
                    color: appState.headphoneMonitor.isConnected ? .green : .red
                )

                badge(
                    text: appState.isHeadphoneLocked ? "Headphone Locked" : "Searching...",
                    icon: "headphones.circle.fill",
                    color: appState.isHeadphoneLocked ? .green : .orange
                )
            }
        }
    }

    private func badge(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    private var controlsCard: some View {
        VStack(spacing: 10) {
            Button(action: {
                appState.toggleTracking()
            }) {
                HStack {
                    Image(systemName: appState.isTrackingActive ? "pause.fill" : "play.fill")
                    Text(appState.isTrackingActive ? "Pause Tracking" : "Start Tracking")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.isTrackingActive ? .orange : .blue)

            Toggle(isOn: Binding(
                get: { appState.settingsStore.settings.headPitchScrollMode },
                set: {
                    appState.settingsStore.settings.headPitchScrollMode = $0
                    appState.settingsStore.save()
                }
            )) {
                Label("Head Pitch Scrolls Page", systemImage: "arrow.up.and.down")
                    .font(.caption.bold())
            }
            .toggleStyle(.switch)
            .padding(.vertical, 2)

            Button(action: {
                appState.startCalibration()
            }) {
                HStack {
                    Image(systemName: "scope")
                    Text("Center Headphone Position")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: {
                appState.showingSettingsSheet = true
            }) {
                HStack {
                    Image(systemName: "gearshape")
                    Text("Settings...")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive, action: {
                appState.emergencyStop()
            }) {
                HStack {
                    Image(systemName: "exclamationmark.octagon.fill")
                    Text("Emergency Stop")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var jblGuideCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(
                    appState.headphoneMonitor.isConnected ?
                        (appState.headphoneMonitor.isJblModel ? "JBL Live 770NC Connected" : appState.headphoneMonitor.deviceName) :
                        "JBL 770NC Not Connected",
                    systemImage: appState.headphoneMonitor.isConnected ? "headphones" : "headphones.slash"
                )
                .font(.caption.bold())
                .foregroundColor(appState.headphoneMonitor.isConnected ? .green : .red)

                Spacer()

                if !appState.headphoneMonitor.isConnected {
                    Button("Connect") {
                        appState.headphoneMonitor.openBluetoothSettings()
                    }
                    .font(.caption2.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("🎧 Single Tap:")
                        .font(.caption2.bold())
                    Text("Left Click (One-Click)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("🎧 Double Tap:")
                        .font(.caption2.bold())
                    Text("Right Click")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("✋ Move Headphone:")
                        .font(.caption2.bold())
                    Text("Moves Cursor Smoothly")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("🎯 Hold Steady:")
                        .font(.caption2.bold())
                    Text("Dwell Auto-Click (Optional)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Real-Time Telemetry")
                .font(.subheadline.bold())

            Group {
                HStack {
                    Text("Yaw / Pitch / Roll:")
                    Spacer()
                    Text(String(format: "%+.1f° / %+.1f° / %+.1f°", appState.currentYaw, appState.currentPitch, appState.currentRoll))
                        .monospacedDigit()
                }

                HStack {
                    Text("1€ Filter Cutoff:")
                    Spacer()
                    Text(String(format: "%.2f Hz", appState.filterCutoffHz))
                        .monospacedDigit()
                }

                HStack {
                    Text("Dwell Progress:")
                    Spacer()
                    Text("\(Int(appState.dwellProgress * 100))%")
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var telemetryBar: some View {
        HStack {
            Text("STATUS: \(appState.statusMessage)")
                .font(.caption.bold())
                .foregroundColor(appState.isTrackingActive ? .green : .secondary)

            Spacer()

            Text(String(format: "FPS: %.1f | Latency: %.1f ms", appState.fps, appState.latencyMs))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }
}
