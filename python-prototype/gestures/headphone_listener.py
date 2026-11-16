"""
Universal Headphone & Audio Device Monitor & Tap Clicker (Python Reference Prototype).
Supports all major headphone brands:
- Apple AirPods (AirPods 1/2/3/4, AirPods Pro, AirPods Max, EarPods)
- Sony (WH-1000XM4/XM5, WF-1000XM4/XM5, LinkBuds, MDR, INZONE)
- Bose (QuietComfort 35/45/Ultra, Noise Cancelling Headphones 700)
- Sennheiser (Momentum, HD 450BT, Accentum, CX)
- Beats (Studio Pro, Solo 4, Fit Pro, Powerbeats)
- JBL (Live 770NC, Live 660NC, Tune 760NC, Quantum, Tour)
- boAt (Rockerz 255/330, Airdopes, Nirvana)
- Samsung (Galaxy Buds, Buds2, Buds Pro, Buds Live, Buds FE, Buds3)
- Google (Pixel Buds, Pixel Buds Pro, Pixel Buds A-Series)
- Jabra (Elite 85h, Elite 7/8/10, Evolve series)
- Anker Soundcore (Space One, Life Q30/Q35, Liberty series)
- Marshall (Major IV/V, Minor, Motif, Monitor II)
- Skullcandy (Crusher Evo, Hesh, Indy, Dime)
- Audio-Technica (ATH-M50xBT2, ATH-SQ1TW)
- Audiophile & Gaming (Shure, Beyerdynamic, Logitech, Razer, SteelSeries, HyperX, Corsair)
- Any standard Bluetooth A2DP, USB headset, or 3.5mm wired headphone.
"""

from dataclasses import dataclass
import json
import os
import subprocess
import sys
import threading
import time
from typing import Callable, Dict, List, Optional, Tuple


@dataclass
class HeadphoneProfile:
    name: str = "Disconnected"
    brand: str = "Unknown"
    category: str = "Headphones"
    is_connected: bool = False
    is_jbl: bool = False


class UniversalHeadphoneMonitor:
    """
    Scans system audio endpoints and Bluetooth registries cross-platform
    to discover connected headphones and categorize their capabilities.
    """

    KNOWN_BRANDS = [
        "airpod", "earpod", "sony", "wh-", "wf-", "linkbuds", "mdr-", "inzone",
        "bose", "quietcomfort", "qc35", "qc45", "soundlink", "sennheiser", "momentum", "accentum",
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

    def __init__(self, check_interval_sec: float = 3.0) -> None:
        self.check_interval = check_interval_sec
        self.current_profile = HeadphoneProfile()
        self._running = False
        self._thread: Optional[threading.Thread] = None

    def start(self) -> None:
        self._running = True
        self._thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._running = False

    def _monitor_loop(self) -> None:
        while self._running:
            self.current_profile = self.detect_headphone()
            time.sleep(self.check_interval)

    @classmethod
    def is_known_brand(cls, name: str) -> bool:
        lower = name.lower()
        return any(b in lower for b in cls.KNOWN_BRANDS)

    @classmethod
    def classify(cls, name: str) -> HeadphoneProfile:
        lower = name.lower()

        # 1. Apple
        if "airpods max" in lower:
            return HeadphoneProfile(name=name, brand="Apple", category="Over-Ear (ANC)", is_connected=True)
        elif "airpods pro" in lower:
            return HeadphoneProfile(name=name, brand="Apple", category="In-Ear / TWS", is_connected=True)
        elif "airpod" in lower:
            return HeadphoneProfile(name=name, brand="Apple", category="In-Ear / TWS", is_connected=True)
        elif "earpod" in lower:
            return HeadphoneProfile(name=name, brand="Apple", category="In-Ear (Wired)", is_connected=True)

        # 2. Beats
        if "beats" in lower or "powerbeats" in lower:
            cat = "Over-Ear" if ("studio" in lower or "solo" in lower) else "In-Ear / TWS"
            return HeadphoneProfile(name=name, brand="Beats", category=cat, is_connected=True)

        # 3. Sony
        if "wh-" in lower or "sony wh" in lower or "mdr-" in lower:
            return HeadphoneProfile(name=name, brand="Sony", category="Over-Ear (ANC)", is_connected=True)
        elif "wf-" in lower or "linkbuds" in lower:
            return HeadphoneProfile(name=name, brand="Sony", category="In-Ear / TWS", is_connected=True)
        elif "sony" in lower:
            return HeadphoneProfile(name=name, brand="Sony", category="Headphones", is_connected=True)

        # 4. Bose
        if "bose" in lower or "quietcomfort" in lower or "qc" in lower:
            cat = "In-Ear / TWS" if "earbud" in lower else "Over-Ear (ANC)"
            return HeadphoneProfile(name=name, brand="Bose", category=cat, is_connected=True)

        # 5. Sennheiser
        if "sennheiser" in lower or "momentum" in lower:
            cat = "In-Ear / TWS" if "true wireless" in lower else "Over-Ear / Studio"
            return HeadphoneProfile(name=name, brand="Sennheiser", category=cat, is_connected=True)

        # 6. JBL
        if "jbl" in lower or "770nc" in lower or ("live" in lower and "770" in lower):
            cat = "In-Ear / Sports" if ("reflect" in lower or "wave" in lower or "vibe" in lower) else "Over-Ear (ANC)"
            return HeadphoneProfile(name=name, brand="JBL", category=cat, is_connected=True, is_jbl=True)

        # 7. boAt
        if "boat" in lower or "rockerz" in lower or "airdopes" in lower:
            cat = "In-Ear / TWS" if "airdopes" in lower else "Wireless Neckband / Over-Ear"
            return HeadphoneProfile(name=name, brand="boAt", category=cat, is_connected=True)

        # 8. Samsung Galaxy Buds
        if "galaxy buds" in lower or "buds+" in lower or "buds2" in lower or "buds3" in lower:
            return HeadphoneProfile(name=name, brand="Samsung", category="In-Ear / TWS", is_connected=True)

        # 9. Google Pixel Buds
        if "pixel buds" in lower:
            return HeadphoneProfile(name=name, brand="Google", category="In-Ear / TWS", is_connected=True)

        # 10. Jabra
        if "jabra" in lower or "evolve" in lower:
            return HeadphoneProfile(name=name, brand="Jabra", category="Headset / TWS", is_connected=True)

        # 11. Anker Soundcore
        if "soundcore" in lower or "space one" in lower or "life q" in lower:
            return HeadphoneProfile(name=name, brand="Soundcore", category="Over-Ear (ANC)", is_connected=True)

        # 12. Gaming Headsets
        if any(b in lower for b in ["logitech", "g733", "g435", "astro", "razer", "blackshark", "kraken", "steelseries", "arctis", "hyperx", "cloud", "corsair"]):
            return HeadphoneProfile(name=name, brand="Gaming Headset", category="Gaming Over-Ear", is_connected=True)

        # 13. Audiophile / Studio
        if any(b in lower for b in ["beyerdynamic", "dt 770", "dt 990", "shure", "aonic", "beoplay", "bowers", "px7", "px8"]):
            return HeadphoneProfile(name=name, brand="Audiophile / Studio", category="High-Fidelity", is_connected=True)

        # 14. Universal Bluetooth / USB / 3.5mm
        return HeadphoneProfile(name=name, brand="Universal", category="Headphones / Headset", is_connected=True, is_jbl="770nc" in lower)

    @classmethod
    def detect_headphone(cls) -> HeadphoneProfile:
        """Discovers current connected headphone endpoint."""
        if sys.platform == "darwin":
            return cls._detect_macos()
        elif sys.platform == "win32":
            return cls._detect_windows()
        return HeadphoneProfile()

    @classmethod
    def _detect_macos(cls) -> HeadphoneProfile:
        try:
            # Query system_profiler for Bluetooth devices
            cmd = ["/usr/sbin/system_profiler", "SPBluetoothDataType", "-json"]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2.5)
            if res.returncode == 0:
                data = json.loads(res.stdout)
                for item in data.get("SPBluetoothDataType", []):
                    for dev in item.get("device_connected", []):
                        for name, props in dev.items():
                            minor_type = props.get("device_minorType", "")
                            services = props.get("device_services", "")
                            is_audio = "Head" in minor_type or "Audio" in minor_type or "A2DP" in services or "AVRCP" in services or cls.is_known_brand(name)
                            if is_audio:
                                return cls.classify(name)
        except Exception:
            pass
        return HeadphoneProfile()

    @classmethod
    def _detect_windows(cls) -> HeadphoneProfile:
        try:
            # Query Windows PnP Audio Endpoints via powershell
            cmd = [
                "powershell", "-NoProfile", "-Command",
                "Get-CimInstance Win32_SoundDevice | Select-Object -ExpandProperty Name"
            ]
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2.5)
            if res.returncode == 0:
                lines = res.stdout.strip().splitlines()
                for line in lines:
                    line = line.strip()
                    if not line:
                        continue
                    lower = line.lower()
                    if "realtek" in lower or "high definition audio" in lower:
                        continue
                    if cls.is_known_brand(line) or "bluetooth" in lower or "headset" in lower or "headphone" in lower or "wireless" in lower:
                        return cls.classify(line)
        except Exception:
            pass
        return HeadphoneProfile()
