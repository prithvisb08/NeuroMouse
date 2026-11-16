"""
Intentional Blink Detector.
Calculates Eye Aspect Ratio (EAR) and classifies blinks temporally
to distinguish spontaneous physiological blinks from intentional click gestures.
"""

import math
from typing import Callable, List, Optional, Tuple


class BlinkDetector:
    """
    EAR-based eye closure tracker and temporal blink classifier.
    """

    def __init__(
        self,
        ear_threshold: float = 0.18,
        min_duration_ms: float = 280.0,
        max_duration_ms: float = 650.0,
        double_blink_window_ms: float = 400.0,
        on_blink_click: Optional[Callable[[bool], None]] = None,
    ) -> None:
        self.ear_threshold = ear_threshold
        self.min_duration_sec = min_duration_ms / 1000.0
        self.max_duration_sec = max_duration_ms / 1000.0
        self.double_blink_window_sec = double_blink_window_ms / 1000.0
        self.on_blink_click = on_blink_click

        self._is_closed: bool = False
        self._closure_start_time: float = 0.0
        self._last_single_blink_time: float = -100.0
        self._pending_single_click: bool = False

    @staticmethod
    def compute_ear(eye_points: List[Tuple[float, float]]) -> float:
        """
        Computes the Eye Aspect Ratio (EAR) given 6 normalized landmark coordinates:
        p1 (outer canthus), p2 (top outer), p3 (top inner),
        p4 (inner canthus), p5 (bottom inner), p6 (bottom outer).
        """
        if len(eye_points) < 6:
            return 0.3

        p1, p2, p3, p4, p5, p6 = eye_points[:6]

        d_v1 = math.hypot(p2[0] - p6[0], p2[1] - p6[1])
        d_v2 = math.hypot(p3[0] - p5[0], p3[1] - p5[1])
        d_h = math.hypot(p1[0] - p4[0], p1[1] - p4[1])

        if d_h < 1e-5:
            return 0.0

        return (d_v1 + d_v2) / (2.0 * d_h)

    def update(
        self,
        left_eye_points: List[Tuple[float, float]],
        right_eye_points: List[Tuple[float, float]],
        timestamp: float,
    ) -> Optional[str]:
        """
        Processes new eye landmarks and detects intentional click gestures.

        Returns:
            "left_click", "right_click", or None.
        """
        ear_left = self.compute_ear(left_eye_points)
        ear_right = self.compute_ear(right_eye_points)
        avg_ear = (ear_left + ear_right) / 2.0

        gesture_event: Optional[str] = None

        # Check pending single click timeout
        if self._pending_single_click:
            if (timestamp - self._last_single_blink_time) > self.double_blink_window_sec:
                self._pending_single_click = False
                gesture_event = "left_click"
                if self.on_blink_click:
                    self.on_blink_click(False)

        # Detect transition into closure
        if avg_ear < self.ear_threshold:
            if not self._is_closed:
                self._is_closed = True
                self._closure_start_time = timestamp
        else:
            # Transition from closed to open
            if self._is_closed:
                duration = timestamp - self._closure_start_time
                self._is_closed = False

                # Classify duration
                if self.min_duration_sec <= duration <= self.max_duration_sec:
                    # Deliberate intentional blink
                    if self._pending_single_click and (timestamp - self._last_single_blink_time) <= self.double_blink_window_sec:
                        # Double blink -> Secondary (Right) Click!
                        self._pending_single_click = False
                        gesture_event = "right_click"
                        if self.on_blink_click:
                            self.on_blink_click(True)
                    else:
                        # First deliberate blink
                        self._pending_single_click = True
                        self._last_single_blink_time = timestamp

        return gesture_event
