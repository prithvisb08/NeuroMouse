import SwiftUI
import AppKit

public struct CursorOverlayView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        GeometryReader { _ in
            if appState.dwellState == .dwelling && appState.dwellProgress > 0.0 {
                let currentPos = appState.cursorController.getCurrentPosition()
                let radius: CGFloat = CGFloat(appState.settingsStore.settings.dwellRadiusPx)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                        .frame(width: radius * 2, height: radius * 2)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(appState.dwellProgress))
                        .stroke(
                            appState.gestureEngine.dwellDetector.isRightClickArmed ? Color.orange : Color.green,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: radius * 2, height: radius * 2)
                        .rotationEffect(.degrees(-90))
                }
                .position(x: currentPos.x, y: currentPos.y)
            }

            if appState.isDragging {
                let currentPos = appState.cursorController.getCurrentPosition()
                HStack(spacing: 4) {
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("DRAG")
                        .font(.system(size: 9, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.orange.opacity(0.85)))
                .shadow(radius: 4)
                .position(x: currentPos.x + 28, y: currentPos.y - 18)
            }
        }
        .allowsHitTesting(false)
        .edgesIgnoringSafeArea(.all)
    }
}

public final class CursorOverlayPanel: NSPanel {
    public init(appState: AppState) {
        super.init(
            contentRect: NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false

        let hostingView = NSHostingView(rootView: CursorOverlayView(appState: appState))
        self.contentView = hostingView
    }
}
