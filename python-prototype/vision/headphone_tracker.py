"""
Headphone & Hand Visual Tracker (Python Prototype).
Tracks headphone movement in front of webcam in real-time.
Supports MediaPipe hand grip tracking and OpenCV adaptive contour tracking.
"""

from dataclasses import dataclass
import time
from typing import Optional, Tuple
import numpy as np

try:
    import cv2
except ImportError:
    cv2 = None

try:
    import mediapipe as mp
except ImportError:
    mp = None


@dataclass
class HeadphoneObservation:
    is_valid: bool
    norm_x: float = 0.5  # 0.0 (left) .. 1.0 (right)
    norm_y: float = 0.5  # 0.0 (top) .. 1.0 (bottom)
    box: Optional[Tuple[int, int, int, int]] = None  # (x, y, w, h)
    confidence: float = 0.0
    mode: str = "none"
    timestamp: float = 0.0


class HeadphoneVisualTracker:
    """
    Tracks the user's headphone (or hand holding headphone) in front of the camera.
    """

    def __init__(self, camera_width: int = 640, camera_height: int = 480):
        self.camera_width = camera_width
        self.camera_height = camera_height

        self.mp_hands = None
        self.hands_detector = None
        if mp is not None and hasattr(mp, "solutions") and hasattr(mp.solutions, "hands"):
            try:
                self.mp_hands = mp.solutions.hands
                self.hands_detector = self.mp_hands.Hands(
                    static_image_mode=False,
                    max_num_hands=1,
                    min_detection_confidence=0.4,
                    min_tracking_confidence=0.4,
                )
            except Exception:
                self.hands_detector = None

        # Fallback background/contour subtractor
        self.bg_subtractor = cv2.createBackgroundSubtractorMOG2(history=50, varThreshold=25, detectShadows=False) if cv2 is not None else None
        self.last_valid_x = 0.5
        self.last_valid_y = 0.5
        self.locked_box = None

    def lock_center(self):
        """Locks the center 25% of camera frame as headphone target."""
        w = int(self.camera_width * 0.25)
        h = int(self.camera_height * 0.25)
        x = int((self.camera_width - w) / 2)
        y = int((self.camera_height - h) / 2)
        self.locked_box = (x, y, w, h)

    def process_frame(self, frame_rgb: np.ndarray, timestamp: float) -> HeadphoneObservation:
        h, w = frame_rgb.shape[:2]

        # Priority 1: MediaPipe Hand Grip Tracking
        if self.hands_detector is not None:
            try:
                results = self.hands_detector.process(frame_rgb)
                if results.multi_hand_landmarks:
                    hand_landmarks = results.multi_hand_landmarks[0]
                    xs = [lm.x for lm in hand_landmarks.landmark]
                    ys = [lm.y for lm in hand_landmarks.landmark]

                    # Mirrored for selfie view: moving hand right -> norm_x increases
                    avg_x = 1.0 - float(np.mean(xs))
                    avg_y = float(np.mean(ys))

                    min_px = int(min(xs) * w)
                    max_px = int(max(xs) * w)
                    min_py = int(min(ys) * h)
                    max_py = int(max(ys) * h)
                    box = (min_px, min_py, max_px - min_px, max_py - min_py)

                    self.last_valid_x = avg_x
                    self.last_valid_y = avg_y

                    return HeadphoneObservation(
                        is_valid=True,
                        norm_x=avg_x,
                        norm_y=avg_y,
                        box=box,
                        confidence=0.90,
                        mode="Hand Grip",
                        timestamp=timestamp,
                    )
            except Exception:
                pass

        # Priority 2: Foreground Motion / Contour Tracking
        if cv2 is not None and self.bg_subtractor is not None:
            gray = cv2.cvtColor(frame_rgb, cv2.COLOR_RGB2GRAY)
            fg_mask = self.bg_subtractor.apply(gray)
            kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
            fg_mask = cv2.morphologyEx(fg_mask, cv2.MORPH_OPEN, kernel)

            contours, _ = cv2.findContours(fg_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            valid_contours = [c for c in contours if cv2.contourArea(c) > 600]

            if valid_contours:
                largest = max(valid_contours, key=cv2.contourArea)
                x, y, bw, bh = cv2.boundingRect(largest)
                cx = (x + bw / 2.0) / float(w)
                cy = (y + bh / 2.0) / float(h)
                # Selfie mirroring
                norm_x = 1.0 - cx
                norm_y = cy

                self.last_valid_x = norm_x
                self.last_valid_y = norm_y

                return HeadphoneObservation(
                    is_valid=True,
                    norm_x=norm_x,
                    norm_y=norm_y,
                    box=(x, y, bw, bh),
                    confidence=0.75,
                    mode="Motion Contour",
                    timestamp=timestamp,
                )

        return HeadphoneObservation(
            is_valid=False,
            norm_x=self.last_valid_x,
            norm_y=self.last_valid_y,
            box=None,
            confidence=0.0,
            mode="none",
            timestamp=timestamp,
        )
