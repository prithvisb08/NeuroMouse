import Foundation
import CoreAudio
import AppKit

@MainActor
public final class HeadphoneConnectionMonitor: ObservableObject {
    @Published public var isConnected: Bool = false
    @Published public var deviceName: String = "Disconnected"
    @Published public var isJblModel: Bool = false

    private final class TimerCleanupBox: @unchecked Sendable {
        var timer: Timer?
    }
    private let cleanupBox = TimerCleanupBox()

    public init() {
        checkConnection()
        startMonitoring()
    }

    public func startMonitoring() {
        cleanupBox.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkConnection()
            }
        }
    }

    public func checkConnection() {
        // 1. Fast check via CoreAudio devices
        if let audioName = checkCoreAudioDevices() {
            self.isConnected = true
            self.deviceName = audioName
            self.isJblModel = audioName.localizedCaseInsensitiveContains("JBL") || audioName.contains("770")
            return
        }

        // 2. Fallback check via system_profiler in background Task
        Task.detached(priority: .background) {
            let (connected, name) = Self.checkBluetoothProfiler()
            await MainActor.run {
                if connected, let name = name {
                    self.isConnected = true
                    self.deviceName = name
                    self.isJblModel = name.localizedCaseInsensitiveContains("JBL") || name.contains("770")
                } else {
                    self.isConnected = false
                    self.deviceName = "Disconnected"
                    self.isJblModel = false
                }
            }
        }
    }

    private func checkCoreAudioDevices() -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else { return nil }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &devices) == noErr else { return nil }

        for id in devices {
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfName: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            if AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &cfName) == noErr,
               let name = cfName?.takeRetainedValue() as String? {
                if name.localizedCaseInsensitiveContains("JBL") || name.contains("770") {
                    return name
                }
            }
        }
        return nil
    }

    nonisolated private static func checkBluetoothProfiler() -> (Bool, String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["SPBluetoothDataType"] as? [[String: Any]] else {
                return (false, nil)
            }

            for item in list {
                if let connected = item["device_connected"] as? [[String: Any]] {
                    for dev in connected {
                        for (name, _) in dev {
                            if name.localizedCaseInsensitiveContains("JBL") || name.contains("770") {
                                return (true, name)
                            }
                        }
                    }
                }
            }
        } catch {
            return (false, nil)
        }
        return (false, nil)
    }

    public func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }

    deinit {
        cleanupBox.timer?.invalidate()
    }
}
