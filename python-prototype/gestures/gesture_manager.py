"""
Unified Gesture Manager.
Coordinates dwell clicking, blink detection, and nod gestures,
routing actions to the cursor controller while enforcing safety invariants.
"""

from typing import Callable, Dict, List, Optional, Tuple

from .dwell_click import DwellClickDetector, DwellState
from .blink_detector import BlinkDetector
from .nod_detector import NodDetector


class GestureManager:
    """
    Central hub for hands-free gesture recognition.
    """

    def __init__(
        self,
        settings: Dict,
        on_click: Optional[Callable[[Tuple[float, float], bool], None]] = None,
        on_scroll: Optional[Callable[[float], None]] = None,
    ) -> None:
        self.settings = settings
        self.on_click = on_click
        self.on_scroll = on_scroll

        self.dwell_enabled = settings.get("dwell_click_enabled", True)
        self.blink_enabled = settings.get("blink_click_enabled", False)
        self.nod_enabled = settings.get("nod_gesture_enabled", False)

        self.dwell_detector = DwellClickDetector(
            dwell_radius_px=float(settings.get("dwell_radius_px", 18.0)),
            dwell_duration_ms=float(settings.get("dwell_duration_ms", 800.0)),
            dwell_cooldown_ms=float(settings.get("dwell_cooldown_ms", 1000.0)),
            rearm_distance_px=float(settings.get("dwell_rearm_distance_px", 25.0)),
            on_click=self.on_click,
        )

        self.blink_detector = BlinkDetector(
            min_duration_ms=float(settings.get("blink_min_duration_ms", 280.0)),
            max_duration_ms=float(settings.get("blink_max_duration_ms", 650.0)),
            on_blink_click=self._handle_blink_click,
        )

        self.nod_detector = NodDetector(
            on_nod=self._handle_nod,
        )

        self._current_cursor_pos: Tuple[float, float] = (0.0, 0.0)

    def _handle_blink_click(self, is_right_click: bool) -> None:
        if self.on_click:
            self.on_click(self._current_cursor_pos, is_right_click)

    def _handle_nod(self) -> None:
        if self.on_click:
            self.on_click(self._current_cursor_pos, False)

    def update(
        self,
        cursor_x: float,
        cursor_y: float,
        delta_yaw_deg: float,
        delta_pitch_deg: float,
        left_eye_landmarks: Optional[List[Tuple[float, float]]],
        right_eye_landmarks: Optional[List[Tuple[float, float]]],
        timestamp: float,
        is_face_locked: bool,
    ) -> Tuple[DwellState, float]:
        """
        Processes multi-modal gesture inputs.

        Returns:
            Tuple of (dwell_state, dwell_progress [0.0, 1.0]).
        """
        self._current_cursor_pos = (cursor_x, cursor_y)

        if not is_face_locked:
            self.dwell_detector.cancel()
            self.nod_detector.reset()
            return DwellState.IDLE, 0.0

        dwell_state = DwellState.IDLE
        dwell_progress = 0.0

        # 1. Dwell Detection
        if self.dwell_enabled:
            dwell_state, dwell_progress = self.dwell_detector.update(
                cursor_x, cursor_y, timestamp, is_face_locked
            )

        # 2. Blink Detection
        if self.blink_enabled and left_eye_landmarks and right_eye_landmarks:
            self.blink_detector.update(
                left_eye_landmarks, right_eye_landmarks, timestamp
            )

        # 3. Nod Detection
        if self.nod_enabled:
            is_dwelling = (dwell_state == DwellState.DWELLING)
            self.nod_detector.update(
                delta_yaw_deg, delta_pitch_deg, timestamp, is_dwelling
            )

        return dwell_state, dwell_progress
