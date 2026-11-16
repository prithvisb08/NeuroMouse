#!/usr/bin/env python3
"""
HeadMotion Mouse — Python High-Speed Reference Prototype.
Autonomous spatial cursor system with craniofacial pose tracking,
Casiez 1€ filtering, dwell clicking, and safety freezing.
"""

import json
import os
import sys
import time
from typing import Dict

# Ensure local modules are importable
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

from camera import CameraManager, FrameProcessor
from vision import FacePosePipeline
from motion import MovementMapper, MappingMode, NeutralPoseCalibrator
from gestures import GestureManager, DwellState
from cursor import CursorController, ScrollController
from ui import DebugWindow


def load_settings(config_path: str) -> Dict:
    """Loads configuration schema with fallback to defaults."""
    default_settings = {
        "camera_index": 0,
        "camera_width": 640,
        "camera_height": 480,
        "target_fps": 30,
        "mapping_mode": "hybrid_absolute",
        "horizontal_sensitivity": 1.0,
        "vertical_sensitivity": 1.0,
        "yaw_range_deg": 15.0,
        "pitch_range_deg": 10.0,
        "horizontal_dead_zone_deg": 1.2,
        "vertical_dead_zone_deg": 1.2,
        "one_euro_min_cutoff": 1.0,
        "one_euro_beta": 0.04,
        "one_euro_d_cutoff": 1.0,
        "parallax_compensation": 0.65,
        "invert_horizontal": False,
        "invert_vertical": False,
        "dwell_click_enabled": True,
        "dwell_duration_ms": 800,
        "dwell_radius_px": 18.0,
        "dwell_cooldown_ms": 1000,
        "dwell_rearm_distance_px": 25.0,
        "blink_click_enabled": False,
        "nod_gesture_enabled": False,
        "scroll_enabled": False,
        "scroll_speed": 1.0,
        "confidence_threshold": 0.65,
        "reentry_stable_frames": 10,
        "physical_mouse_override_pause": True,
        "physical_override_threshold_px": 40.0,
        "privacy_hide_camera_preview": False,
        "start_paused": True,
    }
    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                default_settings.update(loaded)
        except Exception as e:
            print(f"[WARN] Could not parse {config_path}: {e}. Using defaults.")
    return default_settings


def main() -> None:
    config_file = os.path.join(current_dir, "config.json")
    if not os.path.exists(config_file):
        fallback_config = os.path.abspath(os.path.join(current_dir, "..", "shared", "default-settings.json"))
        if os.path.exists(fallback_config):
            config_file = fallback_config

    settings = load_settings(config_file)

    print("==========================================================")
    print("  HEADMOTION MOUSE — High-Speed Python Reference Prototype")
    print("==========================================================")

    # Initialize Cursor Controller
    cursor = CursorController(
        physical_override_pause=settings.get("physical_mouse_override_pause", True),
        override_threshold_px=float(settings.get("physical_override_threshold_px", 40.0)),
    )
    screen_w, screen_h = cursor.get_screen_bounds()
    print(f"[INFO] Active {cursor.platform_name} Screen Geometry: {screen_w:.0f} x {screen_h:.0f} px")

    # Initialize Movement Mapper
    mapping_mode = MappingMode(settings.get("mapping_mode", "hybrid_absolute"))
    mapper = MovementMapper(
        screen_width=screen_w,
        screen_height=screen_h,
        yaw_range_deg=float(settings.get("yaw_range_deg", 15.0)),
        pitch_range_deg=float(settings.get("pitch_range_deg", 10.0)),
        horizontal_dead_zone_deg=float(settings.get("horizontal_dead_zone_deg", 1.2)),
        vertical_dead_zone_deg=float(settings.get("vertical_dead_zone_deg", 1.2)),
        horizontal_sensitivity=float(settings.get("horizontal_sensitivity", 1.0)),
        vertical_sensitivity=float(settings.get("vertical_sensitivity", 1.0)),
        invert_horizontal=bool(settings.get("invert_horizontal", False)),
        invert_vertical=bool(settings.get("invert_vertical", False)),
        mapping_mode=mapping_mode,
        one_euro_min_cutoff=float(settings.get("one_euro_min_cutoff", 1.0)),
        one_euro_beta=float(settings.get("one_euro_beta", 0.04)),
        one_euro_d_cutoff=float(settings.get("one_euro_d_cutoff", 1.0)),
        k_parallax=float(settings.get("parallax_compensation", 0.65)),
    )

    # Initialize Gesture Manager
    gestures = GestureManager(
        settings=settings,
        on_click=lambda pos, is_right: cursor.click(is_right, pos[0], pos[1]),
    )

    # Initialize Scroll Controller
    scroll = ScrollController(
        scroll_threshold_deg=6.0,
        scroll_speed_multiplier=float(settings.get("scroll_speed", 1.0)),
        on_scroll=lambda dy: cursor.scroll(dy),
    )

    # Initialize Neutral Pose Calibrator
    calibrator = NeutralPoseCalibrator(duration_sec=2.5, min_frames=45)

    # Initialize Camera & Vision Pipeline
    cam = CameraManager(
        camera_index=int(settings.get("camera_index", 0)),
        width=int(settings.get("camera_width", 640)),
        height=int(settings.get("camera_height", 480)),
        target_fps=int(settings.get("target_fps", 30)),
    )

    pipeline = FacePosePipeline(
        camera_width=cam.width,
        camera_height=cam.height,
        confidence_threshold=float(settings.get("confidence_threshold", 0.65)),
        reentry_stable_frames=int(settings.get("reentry_stable_frames", 10)),
    )

    frame_proc = FrameProcessor(
        privacy_shutter_enabled=bool(settings.get("privacy_hide_camera_preview", False))
    )
    debug_win = DebugWindow()

    # Open Camera
    if not cam.open():
        print("[WARN] Camera could not be opened. Running in synthetic benchmark mode.")
        use_synthetic = True
    else:
        print("[INFO] Camera device initialized.")
        use_synthetic = False

    is_paused = bool(settings.get("start_paused", True))
    print("[INFO] System ready. Press [Space] to begin tracking, [C] to calibrate neutral baseline.")

    try:
        while True:
            t_start = frame_proc.start_timing()

            if use_synthetic:
                success, frame_rgb, timestamp = cam.create_synthetic_frame()
                time.sleep(1.0 / 30.0)
            else:
                success, frame_rgb, timestamp = cam.read_frame()

            if not success or frame_rgb is None:
                continue

            # Vision Pipeline Inference
            obs = pipeline.process_frame(frame_rgb, timestamp)

            # Calibration handling
            if calibrator.is_active and obs.is_valid:
                finished = calibrator.add_sample(
                    obs.yaw_deg, obs.pitch_deg, obs.roll_deg, timestamp, obs.confidence
                )
                if finished:
                    res = calibrator.finalize()
                    if res.success:
                        mapper.set_baseline(
                            res.yaw_baseline_deg,
                            res.pitch_baseline_deg,
                            res.roll_baseline_deg,
                        )
                        print(f"[CALIBRATION SUCCESS] Baseline: Yaw={res.yaw_baseline_deg:.1f}°, Pitch={res.pitch_baseline_deg:.1f}°, Roll={res.roll_baseline_deg:.1f}°")
                    else:
                        print(f"[CALIBRATION FAILED] {res.error_message}")

            # Cursor & Gesture Execution
            dwell_progress = 0.0
            if not is_paused and obs.is_valid:
                # Map head pose to screen point
                screen_x, screen_y = mapper.process(
                    obs.yaw_deg,
                    obs.pitch_deg,
                    obs.roll_deg,
                    timestamp,
                    obs.tx_mm,
                    obs.ty_mm,
                    obs.tz_mm,
                    is_hybrid_pose=False,
                )

                # Move cursor
                cursor.move_to(screen_x, screen_y, timestamp)

                # Extract eye landmarks if available
                left_eye = obs.landmarks_result.left_eye_points if obs.landmarks_result else None
                right_eye = obs.landmarks_result.right_eye_points if obs.landmarks_result else None

                # Update gestures
                dwell_state, dwell_progress = gestures.update(
                    screen_x,
                    screen_y,
                    obs.yaw_deg - mapper.baseline_yaw,
                    obs.pitch_deg - mapper.baseline_pitch,
                    left_eye,
                    right_eye,
                    timestamp,
                    pipeline.is_face_locked,
                )

                # Update scroll if enabled
                if settings.get("scroll_enabled", False):
                    is_dwelling = (dwell_state == DwellState.DWELLING)
                    scroll.update(
                        obs.pitch_deg - mapper.baseline_pitch,
                        timestamp,
                        is_dwelling,
                    )
            elif not obs.is_valid:
                # Immediate face-loss freeze
                gestures.dwell_detector.cancel()

            # Profiling
            latency = frame_proc.stop_timing(t_start)

            # Debug UI Render
            upper_landmarks = obs.landmarks_result.upper_craniofacial_2d if obs.landmarks_result else None
            key = debug_win.render(
                frame_rgb=frame_proc.prepare_preview_frame(frame_rgb),
                fps=frame_proc.fps,
                latency_ms=latency,
                yaw=obs.yaw_deg,
                pitch=obs.pitch_deg,
                roll=obs.roll_deg,
                one_euro_cutoff=mapper.filter.fx.current_cutoff,
                is_face_locked=pipeline.is_face_locked,
                is_calibrating=calibrator.is_active,
                calibration_progress=calibrator.progress,
                is_paused=is_paused,
                is_privacy_mode=frame_proc.privacy_shutter,
                upper_landmarks=upper_landmarks,
                dwell_progress=dwell_progress,
            )

            if key is not None:
                if key in (ord('q'), ord('Q'), 27):  # Q or Esc
                    print("[INFO] Quit requested.")
                    break
                elif key == ord(' '):  # Space
                    is_paused = not is_paused
                    print(f"[STATE] Tracking {'PAUSED' if is_paused else 'RESUMED'}")
                elif key in (ord('c'), ord('C')):  # C
                    print("[CALIBRATION] Starting neutral pose calibration...")
                    calibrator.start(timestamp)
                elif key in (ord('p'), ord('P')):  # P
                    frame_proc.privacy_shutter = not frame_proc.privacy_shutter
                    print(f"[PRIVACY] Privacy Shutter: {'ENABLED' if frame_proc.privacy_shutter else 'DISABLED'}")
                elif key in (ord('m'), ord('M')):  # M
                    new_mode = MappingMode.DIRECT_ABSOLUTE if mapper.mapping_mode == MappingMode.HYBRID_ABSOLUTE else MappingMode.HYBRID_ABSOLUTE
                    mapper.mapping_mode = new_mode
                    print(f"[MODE] Mapping Mode switched to: {new_mode.value}")

    except KeyboardInterrupt:
        print("\n[INFO] Stopped by user.")
    finally:
        cam.close()
        debug_win.close()
        print("[INFO] Cleanup complete. Shutdown.")


if __name__ == "__main__":
    main()
