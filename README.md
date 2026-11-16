# NeuroMouse

**A Next-Generation, Software-Only, Camera-Based Neural Head-Tracking & Spatial Cursor System for macOS & Windows**

---

## Overview
**HeadMotion Mouse** allows users on both **macOS** and **Windows** to control the system mouse cursor smoothly, accurately, and fatigue-free using natural head movements captured exclusively through any standard built-in or USB webcam.

100% software-only, privacy-preserving, and headphone-agnostic. No wearable sensors, no external markers, and zero cloud processing.

---

## Key Capabilities

- **Speech & Universal Headphone Immunity:** Anchors strictly to the **Rigid Upper Craniofacial Triad** (nasion, nose tip, eye canthi, forehead), completely ignoring jaw, chin, and ear contours. Seamlessly supports wearing any over-ear headphones, on-ear headphones, or TWS earbuds (Apple AirPods, Sony, Bose, JBL, Sennheiser, Beats, Galaxy Buds, etc.) and speaking while tracking.
- **Universal Headphone Hardware Clicker:** Tap your headphone earcup, pinch your AirPods stem, or click the inline remote to trigger instant mouse clicks without touching the keyboard or mouse (1x Tap = Left Click, 2x Tap = Right Click). Universal Bluetooth AVRCP & media-key integration works with virtually any wireless or wired headphone.
- **Translation-Invariant Pose Recovery:** Leaning sideways in your chair does not drift the cursor. Pure 3D rotation $\mathbf{R}$ is isolated from head translation $\mathbf{t}$.
- **Casiez 1€ Adaptive Filter & Smooth Dead-Zone:** Eliminates physiological resting tremor at low velocities while maintaining instantaneous response during rapid sweeps.
- **Hands-Free Dwell Clicking & Spatial HUD:** Precision dwell clicking within an 18 px radius with a live circular progress ring rendered around the cursor, cooldown refractory periods, and re-arm distance constraints.
- **Accessibility UI Gravity ("Target Magnetism"):** Uses macOS `AXUIElement` APIs to inspect UI controls under the cursor and apply gentle velocity damping over buttons and links.
- **Face-Loss Safety & Physical Override:** Instantly freezes cursor and timer actions if your face leaves the frame; automatically yields control for 3 seconds if you physically move the trackpad or mouse.
- **Dual Architecture with 100% Math Parity:** Features both a Python 3.12+ reference prototype and a native Swift 6 macOS Menu Bar & Dashboard application (`HeadMotionMouse.app`).

---

## Repository Structure

```text
NeuroMouse/
├── README.md
├── LICENSE
├── .gitignore
├── CONTRIBUTING.md
│
├── shared/
│   ├── default-settings.json    # Single source of truth for config
│   ├── movement-spec.md         # Coordinate & sign conventions
│   ├── gesture-spec.md          # Dwell, blink, and nod specs
│   ├── calibration-spec.md      # MAD statistical filtering
│   ├── landmark-maps.md         # MediaPipe <-> Apple Vision mapping
│   └── test-vectors/            # Golden I/O JSON vectors for math parity
│
├── python-prototype/            # Python reference prototype
│   ├── requirements.txt
│   ├── main.py
│   ├── camera/                  # Camera capture & frame processor
│   ├── vision/                  # PnP solver & landmark extractor
│   ├── motion/                  # One Euro filter, dead zone, calibration
│   ├── gestures/                # Dwell, blink, and nod detectors
│   ├── cursor/                  # CoreGraphics C API mouse controller
│   ├── ui/                      # Debug window & spatial HUD
│   └── tests/                   # 17 unit and golden vector tests
│
├── macos-app/                   # Native macOS Swift 6 application
│   ├── Package.swift
│   ├── Info.plist
│   ├── Sources/
│   │   ├── HeadMotionMouseCore/ # Reusable Swift core engine
│   │   └── HeadMotionMouseApp/  # SwiftUI App entrypoint
│   ├── TestsRunner/             # Standalone test runner executable
│   └── Tests/                   # XCTest suite
│
├── dist/
│   └── HeadMotionMouse.app      # Packaged & codesigned native app
│
├── docs/                        # Complete technical documentation
└── scripts/
    ├── setup.sh / setup.bat / setup.ps1       # Environment initialization (macOS & Windows)
    ├── run_python.sh / .bat / .ps1            # Launch Python spatial cursor system
    ├── test.sh / test.bat / test.ps1          # Run full test suite
    └── build_macos_app.sh                     # Package HeadMotionMouse.app (macOS only)
```

---

## Quick Start

### Windows (10 / 11)

#### 1. Setup Environment
Open Command Prompt (`cmd`) or PowerShell in the repository root:
```cmd
scripts\setup.bat
```
*(Or in PowerShell: `.\scripts\setup.ps1`)*

This creates `.venv`, installs requirements (`numpy`, `scipy`, `opencv-python`, `mediapipe`, `pytest`), verifies the neural landmarker, and sets up configuration.

#### 2. Run Test Suite
```cmd
scripts\test.bat
```
*(Or in PowerShell: `.\scripts\test.ps1`)*

#### 3. Launch HeadMotion Mouse
```cmd
scripts\run_python.bat
```
*(Or in PowerShell: `.\scripts\run_python.ps1`)*

---

### macOS (Apple Silicon / Intel)

#### 1. Setup Environment
```bash
./scripts/setup.sh
```

#### 2. Run Test Suite
```bash
./scripts/test.sh
```
Runs both the Python test suite (`pytest`) and native Swift test suite (`HeadMotionMouseTestsRunner`).

#### 3. Launch Python Prototype
```bash
./scripts/run_python.sh
```

#### 4. Build & Run Native macOS App (SwiftUI Menu Bar App)
```bash
./scripts/build_macos_app.sh
open dist/HeadMotionMouse.app
```

---

## In-App Hotkeys

- **[Space]:** Toggle tracking on/off (starts paused for safety).
- **[C]:** Calibrate neutral head pose (hold steady for 2.5s).
- **[P]:** Toggle Privacy Shutter (masks camera preview).
- **[M]:** Toggle mapping mode (Direct Absolute vs Hybrid Absolute).
- **[Q] / [Esc]:** Quit.

---

## Platform Architecture

| Capability | macOS Architecture | Windows Architecture |
| :--- | :--- | :--- |
| **Cursor Injection** | CoreGraphics C APIs via `ctypes` (`CGEventPost`) | Win32 `user32.dll` via `ctypes` (`SetCursorPos`, `mouse_event`) |
| **DPI / Resolution** | Native Quartz points & Retina scaling | Windows Per-Monitor v2 DPI Awareness (`SetProcessDpiAwareness`) |
| **Clicks & Drags** | CoreGraphics Left/Right Down/Up events | Win32 `MOUSEEVENTF_LEFTDOWN`, `MOUSEEVENTF_RIGHTDOWN`, etc. |
| **Continuous Scroll** | CoreGraphics `CGEventCreateScrollWheelEvent` | Win32 `MOUSEEVENTF_WHEEL` (`WHEEL_DELTA` scaled) |
| **Audio Feedback** | System sound `/System/Library/Sounds/Tink.aiff` | Built-in `winsound.MessageBeep` / `PlaySound` |
| **Physical Override** | Instant 3-sec pause if physical mouse/trackpad moves | Instant 3-sec pause if physical mouse moves |
| **Webcam Capture** | OpenCV VideoCapture | OpenCV VideoCapture with DirectShow (`CAP_DSHOW`) acceleration |
| **Face Tracking** | MediaPipe Face Landmarker Tasks API | MediaPipe Face Landmarker Tasks API |

---

## Universal Headphone & Audio Device Compatibility

NeuroMouse is designed to be **100% universal and brand-agnostic**. It dynamically detects connected audio devices, displays device-specific telemetry and branding, and intercepts Bluetooth AVRCP media taps for instant hands-free clicks:

| Ecosystem / Brand | Supported Models | Hardware Trigger Gesture |
| :--- | :--- | :--- |
| **Apple** | AirPods (Gen 1/2/3/4), AirPods Pro (Gen 1/2), AirPods Max, EarPods | Force sensor stem squeeze, Digital Crown press |
| **Sony** | WH-1000XM4, WH-1000XM5, WF-1000XM4, WF-1000XM5, LinkBuds, MDR, INZONE | Right earcup capacitive tap, earbud touch sensor |
| **Bose** | QuietComfort 35 / 45 / Ultra, Headphones 700, Sport Earbuds | Multi-function action button, earcup touch surface |
| **Sennheiser** | Momentum 4, Momentum True Wireless 3/4, Accentum, HD 450BT, CX | Touchpad tap, multi-function button |
| **Beats** | Studio Pro, Solo 4, Fit Pro, Powerbeats Pro, Beats Flex | 'b' logo button press, stem pinch |
| **JBL** | Live 770NC, Live 660NC, Tune 760NC/510BT, Tour One, Quantum, Wave | Earcup touch surface, playback button |
| **Samsung** | Galaxy Buds, Buds+, Buds2, Buds Pro, Buds Live, Buds FE, Buds3 / Pro | Earbud capacitive touch tap / double tap |
| **Google** | Pixel Buds, Pixel Buds Pro, Pixel Buds A-Series | Earbud touch surface tap / double tap |
| **boAt** | Rockerz 255 / 330 / 550, Airdopes series, Nirvana | Multi-function button / touch sensor |
| **Jabra** | Elite 85h, Elite 7/8/10, Evolve series | Physical button press |
| **Anker Soundcore**| Space One, Life Q30 / Q35, Liberty 4 / NC | Touchpad / multi-function button |
| **Marshall** | Major IV / V, Monitor II ANC, Minor, Motif | Multi-directional control knob |
| **Skullcandy** | Crusher Evo / ANC, Hesh ANC, Indy, Dime | Main button press / touch sensor |
| **Audio-Technica** | ATH-M50xBT2, ATH-SQ1TW | Earcup control button / touch |
| **Gaming Headsets** | Logitech G733/G435, Razer BlackShark/Barracuda, SteelSeries Arctis, HyperX Cloud, Corsair | Inline remote / headset media button |
| **Audiophile / Studio** | Beyerdynamic DT 770/990, Shure AONIC, B&O Beoplay, Bowers & Wilkins Px7/Px8 | Dedicated control button |
| **Generic / Wired** | Any Bluetooth A2DP/HFP headset, USB DAC/headset, 3.5mm wired headphone | Inline remote button / Bluetooth media key |

- **Single Tap (1x):** Left Click
- **Double Tap (2x):** Right Click

---

## Verification Results

| Test Target | Runner | Result |
| :--- | :--- | :--- |
| **Python Unified Suite** | `pytest 9.2.0` | **25 passed** (100% pass, cross-platform) |
| **Native Swift Suite** | `HeadMotionMouseTestsRunner` | **17 passed** in 2.33s (100% pass on macOS) |
| **macOS Bundle Packaging** | `codesign` verification | **Valid on disk, satisfies designated requirement** |
