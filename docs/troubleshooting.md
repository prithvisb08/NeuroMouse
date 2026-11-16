# Troubleshooting Guide

## 1. Accessibility Permission Denied
**Symptom:** The app runs and tracks head pose, but the system mouse cursor does not move or click.
- **Cause:** macOS requires explicit Accessibility permissions to control the global cursor.
- **Resolution:**
  1. Open **System Settings -> Privacy & Security -> Accessibility**.
  2. Locate `HeadMotionMouse` (or `Terminal` / `iTerm2` if running the Python prototype).
  3. Toggle the checkbox **ON**. If already on, toggle off and on again to clear stale TCC tokens.

## 2. Cursor Drift When Leaning Sideways
**Symptom:** Leaning sideways in your chair causes the cursor to wander across the screen.
- **Cause:** Using hybrid position mapping without calibration, or inaccurate neutral baseline.
- **Resolution:**
  1. Sit in your natural resting posture looking directly at the center of the display.
  2. Press **[C]** (or click "Calibrate Neutral Pose" in Dashboard) and remain steady for 2.5 seconds.
  3. In `shared/default-settings.json`, ensure `mapping_mode` is set to `hybrid_absolute` or `direct_absolute`.

## 3. Accidental Dwell Clicks
**Symptom:** Clicking occurs too quickly before you finish aiming at a target.
- **Resolution:**
  - Increase `dwell_duration_ms` in Settings (e.g. from 800 ms to 1000 ms).
  - Increase `dwell_rearm_distance_px` (default 25 px) to prevent double-click loops.

## 4. Cursor Fighting or Disobeying Trackpad
**Symptom:** Moving your physical mouse or trackpad fights against head tracking.
- **Resolution:**
  - HeadMotion Mouse includes **Physical Input Override Detection**. Moving the physical mouse by $> 40\text{ px}$ automatically yields tracking for 3.0 seconds.
  - To immediately stop tracking at any time, press **Cmd + Shift + Space** (global toggle hotkey) or hit **Emergency Stop** in the Dashboard.

## 5. Cellular Hotspot / Wi-Fi Network Stalls
**Symptom:** Network tools hang on PyPI wheel downloads when tethered to an iPhone Personal Hotspot.
- **Cause:** Certain cellular carriers exhibit IPv6 MTU black-holing on personal hotspots.
- **Resolution:** Run `networksetup -setv6off "Wi-Fi"` to force IPv4 routing.
