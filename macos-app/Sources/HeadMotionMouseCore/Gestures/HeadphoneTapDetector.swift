import Foundation
import AppKit
import MediaPlayer

/// Listens for Bluetooth headphone (e.g. JBL Live 770NC) tap actions.
/// Dispatches:
/// - Single Tap -> Left Click
/// - Double Tap -> Right Click
/// Swallows AVRCP commands to avoid unexpected music playback toggling.
public final class HeadphoneTapDetector: @unchecked Sendable {
    public var onSingleTap: (@Sendable () -> Void)?
    public var onDoubleTap: (@Sendable () -> Void)?
    public var isEnabled: Bool = true

    private var globalMonitor: Any?
    private var pendingTapWorkItem: DispatchWorkItem?
    private let doubleTapWindowSec: Double = 0.35
    private let queue = DispatchQueue.main

    // Media key codes from IOHIDSystem / ev_keymap.h
    private let NX_KEYTYPE_PLAY: Int32 = 16
    private let NX_KEYTYPE_NEXT: Int32 = 17
    private let NX_KEYTYPE_PREVIOUS: Int32 = 18
    private let NX_KEYTYPE_FAST: Int32 = 19
    private let NX_KEYTYPE_REWIND: Int32 = 20

    private var lastTapTime: Double = 0.0

    public init(
        onSingleTap: (@Sendable () -> Void)? = nil,
        onDoubleTap: (@Sendable () -> Void)? = nil
    ) {
        self.onSingleTap = onSingleTap
        self.onDoubleTap = onDoubleTap

        setupRemoteCommandCenter()
        setupSystemDefinedEventMonitor()
    }

    /// Registers with macOS MPRemoteCommandCenter to intercept headphone Bluetooth AVRCP events
    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self, self.isEnabled else { return .commandFailed }
            self.handleTapDetected()
            return .success
        }

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            guard let self = self, self.isEnabled else { return .commandFailed }
            self.handleTapDetected()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, self.isEnabled else { return .commandFailed }
            self.handleTapDetected()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self, self.isEnabled else { return .commandFailed }
            self.handleDoubleTapImmediate()
            return .success
        }
    }

    /// Low-level fallback monitor for NX_SUBTYPE_AUX_CONTROL_BUTTONS
    private func setupSystemDefinedEventMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let self = self, self.isEnabled else { return }
            guard event.subtype.rawValue == 8 else { return }

            let data1 = event.data1
            let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
            let keyFlags = (data1 & 0x0000FFFF)
            let keyState = (keyFlags & 0xFF00) >> 8
            let isKeyDown = (keyState == 0xA)

            guard isKeyDown else { return }

            let now = ProcessInfo.processInfo.systemUptime
            // Debounce duplicates from both monitors
            if now - self.lastTapTime < 0.06 { return }
            self.lastTapTime = now

            if keyCode == self.NX_KEYTYPE_PLAY {
                self.handleTapDetected()
            } else if keyCode == self.NX_KEYTYPE_NEXT || keyCode == self.NX_KEYTYPE_FAST {
                self.handleDoubleTapImmediate()
            }
        }
    }

    private func handleTapDetected() {
        let now = ProcessInfo.processInfo.systemUptime
        lastTapTime = now

        if let existing = pendingTapWorkItem {
            // Second tap arrived within window! -> DOUBLE TAP (Right Click)
            existing.cancel()
            pendingTapWorkItem = nil
            queue.async { [weak self] in
                self?.onDoubleTap?()
            }
        } else {
            // First tap -> wait for potential second tap
            let workItem = DispatchWorkItem { [weak self] in
                self?.pendingTapWorkItem = nil
                self?.onSingleTap?()
            }
            pendingTapWorkItem = workItem
            queue.asyncAfter(deadline: .now() + doubleTapWindowSec, execute: workItem)
        }
    }

    private func handleDoubleTapImmediate() {
        pendingTapWorkItem?.cancel()
        pendingTapWorkItem = nil
        queue.async { [weak self] in
            self?.onDoubleTap?()
        }
    }

    public func cleanup() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        pendingTapWorkItem?.cancel()
        pendingTapWorkItem = nil
    }

    deinit {
        cleanup()
    }
}
