"""
OpenCV Debug Window & Telemetry Display.
Renders real-time video feed, craniofacial anchor triangulation,
orientation vector projection, and telemetry metrics.
"""

from typing import Dict, List, Optional, Tuple
import numpy as np


class DebugWindow:
    """
    Renders diagnostic HUD overlay for the Python reference prototype.
    """

    def __init__(self, window_name: str = "HeadMotion Mouse — Debug HUD") -> None:
        self.window_name = window_name
        self._has_cv2 = False
        try:
            import cv2
            self._cv2 = cv2
            self._has_cv2 = True
        except ImportError:
            self._cv2 = None

    def render(
        self,
        frame_rgb: np.ndarray,
        fps: float,
        latency_ms: float,
        yaw: float,
        pitch: float,
        roll: float,
        one_euro_cutoff: float,
        is_face_locked: bool,
        is_calibrating: bool,
        calibration_progress: float,
        is_paused: bool,
        is_privacy_mode: bool,
        upper_landmarks: Optional[np.ndarray] = None,
        dwell_progress: float = 0.0,
    ) -> Optional[int]:
        """
        Draws HUD graphics and telemetry bar, displaying the window.
        Returns key code if pressed, or None.
        """
        if not self._has_cv2 or frame_rgb is None:
            return None

        cv2 = self._cv2
        h, w = frame_rgb.shape[:2]

        if is_privacy_mode:
            display_bgr = np.zeros((h, w, 3), dtype=np.uint8)
            cv2.putText(
                display_bgr,
                "PRIVACY SHUTTER ACTIVE — VIDEO MASKED",
                (w // 2 - 220, h // 2),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 255, 255),
                2,
                cv2.LINE_AA,
            )
        else:
            display_bgr = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2BGR)

        # 1. Draw Upper Craniofacial Anchor Triad (if face detected)
        if upper_landmarks is not None and len(upper_landmarks) >= 8 and not is_privacy_mode:
            pts = upper_landmarks.astype(np.int32)
            # Draw anchor dots
            for i, (px, py) in enumerate(pts):
                color = (0, 255, 255) if i == 0 else (0, 255, 0)
                cv2.circle(display_bgr, (px, py), 4, color, -1, cv2.LINE_AA)

            # Draw upper craniofacial wireframe lines
            # Nose tip to nasion
            cv2.line(display_bgr, tuple(pts[0]), tuple(pts[1]), (0, 200, 255), 1, cv2.LINE_AA)
            # Nasion to inner canthi
            cv2.line(display_bgr, tuple(pts[1]), tuple(pts[2]), (0, 255, 100), 1, cv2.LINE_AA)
            cv2.line(display_bgr, tuple(pts[1]), tuple(pts[3]), (0, 255, 100), 1, cv2.LINE_AA)
            # Inner canthi to outer canthi
            cv2.line(display_bgr, tuple(pts[2]), tuple(pts[4]), (0, 255, 100), 1, cv2.LINE_AA)
            cv2.line(display_bgr, tuple(pts[3]), tuple(pts[5]), (0, 255, 100), 1, cv2.LINE_AA)

        # 2. Draw Top Status & Telemetry Bar
        overlay = display_bgr.copy()
        cv2.rectangle(overlay, (0, 0), (w, 55), (20, 20, 20), -1)
        cv2.addWeighted(overlay, 0.75, display_bgr, 0.25, 0, display_bgr)

        # Status Badges
        status_text = "PAUSED" if is_paused else ("TRACKING" if is_face_locked else "FACE LOST")
        status_color = (100, 100, 255) if is_paused else ((0, 255, 0) if is_face_locked else (0, 0, 255))
        cv2.putText(display_bgr, f"STATE: {status_text}", (15, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.55, status_color, 2, cv2.LINE_AA)

        # Telemetry Text
        telemetry_str = f"FPS: {fps:.1f} | Latency: {latency_ms:.1f}ms | 1e Cutoff: {one_euro_cutoff:.2f}Hz"
        cv2.putText(display_bgr, telemetry_str, (15, 45), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (220, 220, 220), 1, cv2.LINE_AA)

        # Pose angles
        pose_str = f"Yaw: {yaw:+.1f} deg | Pitch: {pitch:+.1f} deg | Roll: {roll:+.1f} deg"
        cv2.putText(display_bgr, pose_str, (w - 380, 22), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (200, 255, 200), 1, cv2.LINE_AA)

        # Calibration Prompt
        if is_calibrating:
            cal_w = int(200 * calibration_progress)
            cv2.rectangle(display_bgr, (w // 2 - 100, h - 45), (w // 2 + 100, h - 25), (60, 60, 60), -1)
            cv2.rectangle(display_bgr, (w // 2 - 100, h - 45), (w // 2 - 100 + cal_w, h - 25), (0, 200, 255), -1)
            cv2.putText(
                display_bgr,
                "CALIBRATING NEUTRAL POSE — HOLD STILL",
                (w // 2 - 180, h - 55),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.5,
                (0, 255, 255),
                1,
                cv2.LINE_AA,
            )

        # Hotkeys help footer
        help_text = "[C] Calibrate  |  [Space] Pause/Resume  |  [P] Privacy  |  [Q/Esc] Quit"
        cv2.putText(display_bgr, help_text, (15, h - 12), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (150, 150, 150), 1, cv2.LINE_AA)

        cv2.imshow(self.window_name, display_bgr)
        key = cv2.waitKey(1) & 0xFF
        return key if key != 255 else None

    def close(self) -> None:
        if self._has_cv2:
            try:
                self._cv2.destroyWindow(self.window_name)
            except Exception:
                pass
