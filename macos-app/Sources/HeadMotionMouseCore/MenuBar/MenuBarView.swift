import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var appState: AppState
    var openDashboard: () -> Void

    public init(appState: AppState, openDashboard: @escaping () -> Void) {
        self.appState = appState
        self.openDashboard = openDashboard
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(appState.isTrackingActive ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(appState.statusMessage)
                    .font(.headline)
            }

            Divider()

            Button(appState.isTrackingActive ? "Pause Tracking" : "Resume Tracking") {
                appState.toggleTracking()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])

            Button("Recalibrate Neutral Pose...") {
                appState.startCalibration()
            }

            Button(appState.isPrivacyShutterActive ? "Show Camera Video" : "Mask Camera (Privacy Shutter)") {
                appState.isPrivacyShutterActive.toggle()
            }

            Divider()

            Button("Open Dashboard...") {
                openDashboard()
            }

            Divider()

            Button("Quit HeadMotion Mouse") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(12)
        .frame(width: 240)
    }
}
