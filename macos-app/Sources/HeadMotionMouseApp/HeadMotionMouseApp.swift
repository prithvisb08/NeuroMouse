import SwiftUI
import AppKit
import HeadMotionMouseCore

@main
struct HeadMotionMouseApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("HeadMotion Mouse Dashboard") {
            DashboardWindowView(appState: appState)
                .onAppear {
                    // Initialize HUD panel
                    let panel = CursorOverlayPanel(appState: appState)
                    panel.orderFrontRegardless()
                }
        }
        .windowResizability(.contentSize)

        MenuBarExtra("HeadMotion", systemImage: appState.isTrackingActive ? "eye.circle.fill" : "eye.circle") {
            MenuBarView(appState: appState) {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.title.contains("Dashboard") {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }
}
