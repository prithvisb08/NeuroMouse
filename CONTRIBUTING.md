# Contributing to HeadMotion Mouse

Thank you for contributing to HeadMotion Mouse.

## Architectural Principles
1. **Safety & Zero Disruption:** The system must never trap the cursor or fight physical user mouse movements.
2. **Speech & Headphone Immunity:** Always anchor to the Upper Craniofacial Triad (nasion, nose tip, eye canthi, forehead) to prevent artifacts from speech or headphones.
3. **Cross-Language Math Parity:** All signal processing algorithms (One Euro filter, dead-zone, roll decomposition, calibration) must strictly match between Python and Swift against the test vectors in `shared/test-vectors/`.
4. **Deterministic Testing:** Tests must run without requiring live webcam hardware or TCC permission dialogs by utilizing recorded and synthetic landmark sequences.

## Development Workflow
1. Ensure Python 3.11+ / 3.12+ and Swift 6 / Xcode CLI tools are installed.
2. Run `./scripts/setup.sh` to initialize environments and dependencies.
3. Run `./scripts/test.sh` to execute the full cross-platform test suite.
