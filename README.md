# NeuroMouse

**A Next-Generation, Software-Only, Camera-Based Neural Head-Tracking & Spatial Cursor System for macOS & Windows**

---

## Overview
**HeadMotion Mouse** allows users on both **macOS** and **Windows** to control the system mouse cursor smoothly, accurately, and fatigue-free using natural head movements captured exclusively through any standard built-in or USB webcam.

100% software-only, privacy-preserving, and headphone-agnostic. No wearable sensors, no external markers, and zero cloud processing.

---

## Key Capabilities

- **Speech & Headphone Immunity:** Anchors strictly to the **Rigid Upper Craniofacial Triad** (nasion, nose tip, eye canthi, forehead), completely ignoring jaw, chin, and ear contours. Seamlessly supports wearing over-ear headphones (such as the **JBL Live 770NC**) and speaking while tracking.
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

## Verification Results

| Test Target | Runner | Result |
| :--- | :--- | :--- |
| **Python Unified Suite** | `pytest 9.2.0` | **24 passed** (100% pass, cross-platform) |
| **Native Swift Suite** | `HeadMotionMouseTestsRunner` | **12 passed** in 1.30s (100% pass on macOS) |
| **macOS Bundle Packaging** | `codesign` verification | **Valid on disk, satisfies designated requirement** |
# NeuroMouse
