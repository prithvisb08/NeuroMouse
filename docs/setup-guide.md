# Setup & Installation Guide

## 1. System Requirements
- **Hardware:** Apple Silicon Mac (`arm64`: MacBook Air, MacBook Pro, Mac mini, Mac Studio, iMac with M1 or newer).
- **Camera:** Built-in FaceTime HD camera or external UVC webcam.
- **Operating System:** macOS 14.0 Sonoma or newer.
- **Software Dependencies:**
  - Python 3.11+ / 3.12+ (or `uv`)
  - Xcode Command Line Tools (`xcode-select --install`) with Swift 6 / 5.10.

## 2. Automated One-Step Setup
Run the setup script from the repository root:
```bash
./scripts/setup.sh
```
This automatically:
1. Inspects host architecture and toolchain.
2. Creates `.venv` and installs Python scientific dependencies (`numpy`, `scipy`, `pytest`).
3. Downloads and verifies the MediaPipe `face_landmarker.task` model with pinned SHA-256 checksum.
4. Symlinks the shared configuration schema.

## 3. Launching the Python Reference Prototype
```bash
./scripts/run_python.sh
```
- Press **[Space]** to start or pause cursor tracking.
- Press **[C]** while looking comfortably forward to calibrate your neutral baseline.
- Press **[P]** to toggle Privacy Shutter mode.
- Press **[M]** to toggle between Direct Absolute and Hybrid Auto-Pan modes.
- Press **[Q]** or **[Esc]** to exit.

## 4. Building & Running the Native macOS Application
To compile and package the native macOS menu bar and dashboard app bundle:
```bash
./scripts/build_macos_app.sh
```
This creates:
`dist/HeadMotionMouse.app`

Launch the app:
```bash
open dist/HeadMotionMouse.app
```

## 5. macOS Permissions Setup
HeadMotion Mouse requires two macOS system permissions:
1. **Camera Access:** Prompts automatically on first launch to capture video from the webcam.
2. **Accessibility Access:** Required to move the system cursor and inject dwell mouse clicks.
   - Go to: **System Settings -> Privacy & Security -> Accessibility**.
   - Ensure `HeadMotionMouse` (or your Terminal / IDE if running via CLI) is toggled **ON**.
