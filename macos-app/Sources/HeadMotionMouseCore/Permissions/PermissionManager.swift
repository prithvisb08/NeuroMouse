import Foundation
import AVFoundation
import ApplicationServices
import SwiftUI

@MainActor
public final class PermissionManager: ObservableObject {
    @Published public var isCameraAuthorized: Bool = false
    @Published public var isAccessibilityAuthorized: Bool = false

    private final class MonitorCleanupBox: @unchecked Sendable {
        var pollTimer: Timer?
        var activeObserver: Any?
    }
    private let cleanupBox = MonitorCleanupBox()

    public init() {
        checkPermissions()
        startPeriodicCheck()
    }

    public func startPeriodicCheck() {
        cleanupBox.pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissions()
            }
        }

        cleanupBox.activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPermissions()
            }
        }
    }

    public func checkPermissions() {
        checkCameraPermission()
        checkAccessibilityPermission()
    }

    public func checkCameraPermission() {
        let granted = (AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
        if self.isCameraAuthorized != granted {
            self.isCameraAuthorized = granted
        }
    }

    public func requestCameraPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        self.isCameraAuthorized = granted
        return granted
    }

    public func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if self.isAccessibilityAuthorized != trusted {
            self.isAccessibilityAuthorized = trusted
        }
    }

    public func promptAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        self.isAccessibilityAuthorized = AXIsProcessTrustedWithOptions(options)
    }

    public func resetAccessibilityTCC() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "com.headmotion.mouse"]
        try? process.run()
        process.waitUntilExit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.promptAccessibilityPermission()
        }
    }

    public func openSystemAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func openSystemCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    deinit {
        cleanupBox.pollTimer?.invalidate()
        if let obs = cleanupBox.activeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
