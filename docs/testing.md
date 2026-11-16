# Verification & Testing Guide

## 1. Automated Test Architecture
HeadMotion Mouse enforces mathematical parity across Python and Swift implementations through deterministic golden test vectors located in `shared/test-vectors/`:
- `one_euro.json`: Golden input/output vectors for the Casiez 1€ filter.
- `dead_zone.json`: Continuous $C^0$ / $C^1$ quadratic dead-zone outputs.
- `calibration.json`: Normal-consistent Median Absolute Deviation (MAD) and trimmed mean baseline outputs.
- `parallax.json`: Translation compensation angle transformations.
- `movement_mapper.json`: Roll-horizon coordinate projection and screen bounds mapping.

## 2. Running All Tests
To execute both the Python and Native Swift test suites with a single command:
```bash
./scripts/test.sh
```

### Python Suite (`pytest`)
Executes all 17 unit and regression tests:
```bash
.venv/bin/pytest python-prototype/tests/ -v
```
Test modules:
- `test_one_euro_filter.py`: 1€ adaptive filter behavior against golden vectors and reset handling.
- `test_motion_mapper.py`: Dead-zone curve, roll-horizon rotation, screen bounds clamping.
- `test_calibration.py`: MAD outlier rejection, excessive motion detection, insufficient frame aborts.
- `test_parallax.py`: Parallax compensation vectors and lean-only translation-invariance regression.
- `test_head_pose.py`: Canonical 3D anchor points, Euler $YXZ$ decomposition, pinhole projection.
- `test_gestures.py`: Dwell click FSM, face-loss timer abortion, blink temporal windows, nod impulse.

### Native Swift Suite (`HeadMotionMouseTestsRunner`)
Executes 12 native Swift tests in `macos-app/`:
```bash
cd macos-app && swift run HeadMotionMouseTestsRunner
```
Verifies that the compiled Swift 6 `HeadMotionMouseCore` library exactly reproduces the golden test vectors within floating-point tolerance `1e-5` to `1e-6`.
