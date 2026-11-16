import Foundation
import CoreAudio
import AppKit

public struct HeadphoneProfile: Sendable, Equatable {
    public let name: String
    public let brand: String
    public let category: String
    public let systemIconName: String
    public let isJbl: Bool

    public init(
        name: String,
        brand: String = "Universal",
        category: String = "Headphones",
        systemIconName: String = "headphones",
        isJbl: Bool = false
    ) {
        self.name = name
        self.brand = brand
        self.category = category
        self.systemIconName = systemIconName
        self.isJbl = isJbl
    }
}

@MainActor
public final class HeadphoneConnectionMonitor: ObservableObject {
    @Published public var isConnected: Bool = false
    @Published public var deviceName: String = "Disconnected"
    @Published public var deviceBrand: String = "None"
    @Published public var deviceCategory: String = "Headphones"
    @Published public var systemIconName: String = "headphones"
    @Published public var isJblModel: Bool = false

    @Published public var isAirPods: Bool = false
    @Published public var isSony: Bool = false
    @Published public var isBose: Bool = false
    @Published public var isBeats: Bool = false
    @Published public var isSennheiser: Bool = false
    @Published public var isGalaxyBuds: Bool = false
    @Published public var isPixelBuds: Bool = false
    @Published public var isBoat: Bool = false

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
        if let profile = checkCoreAudioDevices() {
            self.applyProfile(profile)
            return
        }

        // 2. Fallback check via system_profiler in background Task
        Task.detached(priority: .background) {
            let (connected, profile) = Self.checkBluetoothProfiler()
            await MainActor.run {
                if connected, let profile = profile {
                    self.applyProfile(profile)
                } else {
                    self.clearConnection()
                }
            }
        }
    }

    private func applyProfile(_ profile: HeadphoneProfile) {
        self.isConnected = true
        self.deviceName = profile.name
        self.deviceBrand = profile.brand
        self.deviceCategory = profile.category
        self.systemIconName = profile.systemIconName
        self.isJblModel = profile.isJbl

        let lower = profile.name.lowercased()
        self.isAirPods = lower.contains("airpod")
        self.isSony = lower.contains("sony") || lower.contains("wh-") || lower.contains("wf-") || lower.contains("linkbuds")
        self.isBose = lower.contains("bose") || lower.contains("quietcomfort")
        self.isBeats = lower.contains("beats") || lower.contains("powerbeats")
        self.isSennheiser = lower.contains("sennheiser") || lower.contains("momentum")
        self.isGalaxyBuds = lower.contains("galaxy buds") || lower.contains("buds+") || lower.contains("buds2") || lower.contains("buds3")
        self.isPixelBuds = lower.contains("pixel buds")
        self.isBoat = lower.contains("boat") || lower.contains("rockerz") || lower.contains("airdopes")
    }

    private func clearConnection() {
        self.isConnected = false
        self.deviceName = "Disconnected"
        self.deviceBrand = "None"
        self.deviceCategory = "Headphones"
        self.systemIconName = "headphones.slash"
        self.isJblModel = false
        self.isAirPods = false
        self.isSony = false
        self.isBose = false
        self.isBeats = false
        self.isSennheiser = false
        self.isGalaxyBuds = false
        self.isPixelBuds = false
        self.isBoat = false
    }

    private func checkCoreAudioDevices() -> HeadphoneProfile? {
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

        var candidates: [HeadphoneProfile] = []

        for id in devices {
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var cfName: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &cfName) == noErr,
                  let name = cfName?.takeRetainedValue() as String? else {
                continue
            }

            var transAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var transportType: UInt32 = 0
            var tSize = UInt32(MemoryLayout<UInt32>.size)
            _ = AudioObjectGetPropertyData(id, &transAddress, 0, nil, &tSize, &transportType)

            // Check if device has audio output streams
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            _ = AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize)
            let hasOutput = (streamSize > 0)

            if let profile = Self.evaluateDevice(name: name, transportType: transportType, hasOutput: hasOutput) {
                // If it is an active output stream, return immediately
                if hasOutput {
                    return profile
                }
                candidates.append(profile)
            }
        }

        return candidates.first
    }

    nonisolated private static func checkBluetoothProfiler() -> (Bool, HeadphoneProfile?) {
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
                        for (name, rawDetails) in dev {
                            let details = rawDetails as? [String: Any] ?? [:]
                            let minorType = details["device_minorType"] as? String ?? ""
                            let services = details["device_services"] as? String ?? ""

                            let isAudioDevice = minorType.localizedCaseInsensitiveContains("Head") ||
                                                minorType.localizedCaseInsensitiveContains("Audio") ||
                                                minorType.localizedCaseInsensitiveContains("Speaker") ||
                                                services.contains("A2DP") ||
                                                services.contains("HFP") ||
                                                services.contains("AVRCP")

                            if isAudioDevice || isKnownHeadphoneBrand(name) {
                                let profile = classifyHeadphone(name: name)
                                return (true, profile)
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

    nonisolated public static func evaluateDevice(name: String, transportType: UInt32, hasOutput: Bool) -> HeadphoneProfile? {
        // Exclude internal built-in speakers & microphones
        let lower = name.lowercased()
        if lower.contains("macbook") ||
           lower.contains("internal speaker") ||
           lower.contains("internal mic") ||
           lower.contains("built-in speaker") ||
           lower.contains("built-in microphone") ||
           lower.contains("imac speaker") ||
           lower.contains("mac mini speaker") ||
           lower.contains("studio display") {
            return nil
        }

        // Transport constants:
        // 'blue' = 0x626c7565 (1651275109)
        // 'blea' = 0x626c6561 (1651274849)
        // 'usb ' = 0x75736220 (1970496032)
        // 'bltn' = 0x626c746e (1651274862)
        let isBluetooth = (transportType == 0x626c7565 || transportType == 0x626c6561)
        let isUSB = (transportType == 0x75736220)
        let isExternalHeadphoneJack = lower.contains("external headphone") || lower.contains("headphones") || lower.contains("headset")

        if isBluetooth || isUSB || isExternalHeadphoneJack || isKnownHeadphoneBrand(name) {
            return classifyHeadphone(name: name)
        }

        return nil
    }

    nonisolated public static func isKnownHeadphoneBrand(_ name: String) -> Bool {
        let l = name.lowercased()
        let brands = [
            "airpod", "earpod", "sony", "wh-", "wf-", "linkbuds", "mdr-", "inzone",
            "bose", "quietcomfort", "soundlink", "sennheiser", "momentum", "accentum",
            "jbl", "live 770", "tune", "quantum", "reflect", "beats", "powerbeats",
            "solo", "galaxy buds", "buds+", "buds2", "buds3", "pixel buds", "boat",
            "rockerz", "airdopes", "nirvana", "jabra", "elite", "evolve", "soundcore",
            "space one", "life q", "liberty", "marshall", "major", "minor", "motif",
            "skullcandy", "crusher", "hesh", "indy", "audio-technica", "ath-", "shure",
            "aonic", "beyerdynamic", "dt 770", "dt 990", "logitech", "g733", "g435",
            "razer", "blackshark", "kraken", "barracuda", "steelseries", "arctis",
            "hyperx", "cloud", "corsair", "virtuoso", "beoplay", "bowers", "px7", "px8",
            "headphone", "headset", "earphone", "earbud"
        ]
        return brands.contains { l.contains($0) }
    }

    nonisolated public static func classifyHeadphone(name: String) -> HeadphoneProfile {
        let l = name.lowercased()

        // 1. Apple Ecosystem
        if l.contains("airpods max") {
            return HeadphoneProfile(name: name, brand: "Apple", category: "Over-Ear (ANC)", systemIconName: "airpodsmax")
        } else if l.contains("airpods pro") {
            return HeadphoneProfile(name: name, brand: "Apple", category: "In-Ear / TWS", systemIconName: "airpodspro")
        } else if l.contains("airpod") {
            return HeadphoneProfile(name: name, brand: "Apple", category: "In-Ear / TWS", systemIconName: "airpods.gen3")
        } else if l.contains("earpod") {
            return HeadphoneProfile(name: name, brand: "Apple", category: "In-Ear (Wired)", systemIconName: "earbuds")
        }

        // 2. Beats
        if l.contains("beats") || l.contains("powerbeats") {
            let cat = (l.contains("studio") || l.contains("solo")) ? "Over-Ear" : "In-Ear / TWS"
            let icon = (cat == "Over-Ear") ? "headphones" : "earbuds"
            return HeadphoneProfile(name: name, brand: "Beats", category: cat, systemIconName: icon)
        }

        // 3. Sony
        if l.contains("wh-") || l.contains("sony wh") || l.contains("mdr-") {
            return HeadphoneProfile(name: name, brand: "Sony", category: "Over-Ear (ANC)", systemIconName: "headphones")
        } else if l.contains("wf-") || l.contains("linkbuds") {
            return HeadphoneProfile(name: name, brand: "Sony", category: "In-Ear / TWS", systemIconName: "earbuds")
        } else if l.contains("sony") {
            return HeadphoneProfile(name: name, brand: "Sony", category: "Headphones", systemIconName: "headphones")
        }

        // 4. Bose
        if l.contains("bose") || l.contains("quietcomfort") || l.contains("qc ") || l.contains("qc35") || l.contains("qc45") {
            let cat = l.contains("earbud") ? "In-Ear / TWS" : "Over-Ear (ANC)"
            let icon = (cat == "Over-Ear (ANC)") ? "headphones" : "earbuds"
            return HeadphoneProfile(name: name, brand: "Bose", category: cat, systemIconName: icon)
        }

        // 5. Sennheiser
        if l.contains("sennheiser") || l.contains("momentum") || l.contains("accentum") {
            let cat = l.contains("true wireless") ? "In-Ear / TWS" : "Over-Ear / Studio"
            let icon = (cat == "In-Ear / TWS") ? "earbuds" : "headphones"
            return HeadphoneProfile(name: name, brand: "Sennheiser", category: cat, systemIconName: icon)
        }

        // 6. JBL
        if l.contains("jbl") || (l.contains("live") && l.contains("770")) || l.contains("770nc") {
            let cat: String
            let icon: String
            if l.contains("reflect") || l.contains("endurance") || l.contains("wave") || l.contains("vibe") {
                cat = "In-Ear / Sports TWS"
                icon = "earbuds"
            } else if l.contains("tune 5") || l.contains("tune 6") {
                cat = "On-Ear"
                icon = "headphones"
            } else {
                cat = "Over-Ear (ANC)"
                icon = "headphones"
            }
            return HeadphoneProfile(name: name, brand: "JBL", category: cat, systemIconName: icon, isJbl: true)
        }

        // 7. boAt
        if l.contains("boat") || l.contains("rockerz") || l.contains("airdopes") || l.contains("nirvana") {
            let cat = l.contains("airdopes") ? "In-Ear / TWS" : "Wireless Neckband / Over-Ear"
            let icon = l.contains("airdopes") ? "earbuds" : "headphones"
            return HeadphoneProfile(name: name, brand: "boAt", category: cat, systemIconName: icon)
        }

        // 8. Samsung Galaxy Buds
        if l.contains("galaxy buds") || l.contains("buds+") || l.contains("buds2") || l.contains("buds3") || l.contains("buds live") {
            return HeadphoneProfile(name: name, brand: "Samsung", category: "In-Ear / TWS", systemIconName: "earbuds")
        }

        // 9. Google Pixel Buds
        if l.contains("pixel buds") {
            return HeadphoneProfile(name: name, brand: "Google", category: "In-Ear / TWS", systemIconName: "earbuds")
        }

        // 10. Jabra
        if l.contains("jabra") || l.contains("evolve") {
            return HeadphoneProfile(name: name, brand: "Jabra", category: "Headset / TWS", systemIconName: "headset")
        }

        // 11. Anker Soundcore
        if l.contains("soundcore") || l.contains("space one") || l.contains("life q") {
            let cat = l.contains("liberty") ? "In-Ear / TWS" : "Over-Ear (ANC)"
            let icon = (cat == "Over-Ear (ANC)") ? "headphones" : "earbuds"
            return HeadphoneProfile(name: name, brand: "Soundcore", category: cat, systemIconName: icon)
        }

        // 12. Marshall
        if l.contains("marshall") || l.contains("major") {
            return HeadphoneProfile(name: name, brand: "Marshall", category: "Over-Ear / On-Ear", systemIconName: "headphones")
        }

        // 13. Skullcandy
        if l.contains("skullcandy") || l.contains("crusher") || l.contains("hesh") {
            return HeadphoneProfile(name: name, brand: "Skullcandy", category: "Over-Ear / TWS", systemIconName: "headphones")
        }

        // 14. Audio-Technica
        if l.contains("audio-technica") || l.contains("ath-") {
            return HeadphoneProfile(name: name, brand: "Audio-Technica", category: "Studio Monitor / TWS", systemIconName: "headphones")
        }

        // 15. Gaming Headsets (Logitech, Razer, SteelSeries, HyperX, Corsair)
        if l.contains("logitech") || l.contains("g733") || l.contains("g435") || l.contains("astro") ||
           l.contains("razer") || l.contains("blackshark") || l.contains("kraken") ||
           l.contains("steelseries") || l.contains("arctis") ||
           l.contains("hyperx") || l.contains("cloud") ||
           l.contains("corsair") || l.contains("virtuoso") {
            return HeadphoneProfile(name: name, brand: "Gaming Headset", category: "Gaming Over-Ear", systemIconName: "headset")
        }

        // 16. Audiophile (Shure, Beyerdynamic, B&O, Bowers & Wilkins)
        if l.contains("beyerdynamic") || l.contains("dt 770") || l.contains("dt 990") ||
           l.contains("shure") || l.contains("aonic") ||
           l.contains("beoplay") || l.contains("bowers") || l.contains("px7") || l.contains("px8") {
            return HeadphoneProfile(name: name, brand: "Audiophile / Studio", category: "High-Fidelity", systemIconName: "headphones")
        }

        // 17. Universal Headphone / Headset Fallback
        return HeadphoneProfile(name: name, brand: "Universal", category: "Headphone / Headset", systemIconName: "headphones", isJbl: (l.contains("jbl") || l.contains("770nc")))
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
