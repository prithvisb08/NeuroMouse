"""
Dwell Click Detector.
Monitors cursor spatial stability and triggers an intentional click when the cursor
remains within a designated spatial threshold for the target dwell duration.
Includes cooldown refractory periods and re-arming displacement requirements.
"""

from enum import Enum
import math
from typing import Callable, Optional, Tuple


class DwellState(str, Enum):
    IDLE = "idle"
    DWELLING = "dwelling"
    TRIGGERED = "triggered"
    COOLDOWN = "cooldown"


class DwellClickDetector:
    """
    Finite State Machine managing spatial dwell clicking and HUD countdown progress.
    """

    def __init__(
        self,
        dwell_radius_px: float = 18.0,
        dwell_duration_ms: float = 800.0,
        dwell_cooldown_ms: float = 1000.0,
        rearm_distance_px: float = 25.0,
        on_click: Optional[Callable[[Tuple[float, float], bool], None]] = None,
    ) -> None:
        self.dwell_radius_px = dwell_radius_px
        self.dwell_duration_sec = dwell_duration_ms / 1000.0
        self.cooldown_sec = dwell_cooldown_ms / 1000.0
        self.rearm_distance_px = rearm_distance_px
        self.on_click = on_click

        self.state: DwellState = DwellState.IDLE
        self.anchor_x: float = 0.0
        self.anchor_y: float = 0.0
        self.start_time: float = 0.0
        self.last_click_time: float = -100.0
        self.last_click_pos: Tuple[float, float] = (0.0, 0.0)
        self.right_click_armed: bool = False

    def arm_right_click(self) -> None:
        """Arms the next dwell click to execute as a secondary (right) click."""
        self.right_click_armed = True

    @property
    def progress(self) -> float:
        """Returns dwell progress in range [0.0, 1.0]."""
        if self.state == DwellState.DWELLING:
            return min(1.0, max(0.0, (self._last_time - self.start_time) / self.dwell_duration_sec))
        elif self.state == DwellState.TRIGGERED:
            return 1.0
        return 0.0

    def cancel(self) -> None:
        """Aborts any active dwell countdown and resets state to IDLE."""
        self.state = DwellState.IDLE
        self.start_time = 0.0
        self.right_click_armed = False

    def update(
        self,
        cursor_x: float,
        cursor_y: float,
        timestamp: float,
        is_face_locked: bool = True,
    ) -> Tuple[DwellState, float]:
        """
        Updates the dwell state machine with the latest cursor position.

        Returns:
            Tuple of (current_state, progress [0.0, 1.0]).
        """
        self._last_time = timestamp

        # Safety: Face loss immediately cancels dwell
        if not is_face_locked:
            self.cancel()
            return DwellState.IDLE, 0.0

        # Check cooldown refractory period
        if timestamp - self.last_click_time < self.cooldown_sec:
            self.state = DwellState.COOLDOWN
            return DwellState.COOLDOWN, 0.0

        # Check re-arm distance constraint after cooldown
        dist_from_last_click = math.hypot(
            cursor_x - self.last_click_pos[0],
            cursor_y - self.last_click_pos[1],
        )
        if dist_from_last_click < self.rearm_distance_px and self.last_click_time > 0:
            self.state = DwellState.IDLE
            return DwellState.IDLE, 0.0

        # Main Dwell State Logic
        if self.state == DwellState.IDLE or self.state == DwellState.COOLDOWN:
            # Anchor at current position and start timer
            self.state = DwellState.DWELLING
            self.anchor_x = cursor_x
            self.anchor_y = cursor_y
            self.start_time = timestamp
            return DwellState.DWELLING, 0.0

        elif self.state == DwellState.DWELLING:
            # Check displacement from anchor
            displacement = math.hypot(cursor_x - self.anchor_x, cursor_y - self.anchor_y)
            if displacement > self.dwell_radius_px:
                # Movement exceeded dwell radius: cancel and re-anchor
                self.anchor_x = cursor_x
                self.anchor_y = cursor_y
                self.start_time = timestamp
                return DwellState.DWELLING, 0.0

            # Calculate progress
            elapsed = timestamp - self.start_time
            if elapsed >= self.dwell_duration_sec:
                # Trigger click event!
                self.state = DwellState.TRIGGERED
                self.last_click_time = timestamp
                self.last_click_pos = (self.anchor_x, self.anchor_y)
                is_right = self.right_click_armed
                self.right_click_armed = False

                if self.on_click is not None:
                    self.on_click((self.anchor_x, self.anchor_y), is_right)

                return DwellState.TRIGGERED, 1.0
            else:
                return DwellState.DWELLING, elapsed / self.dwell_duration_sec

        elif self.state == DwellState.TRIGGERED:
            self.state = DwellState.COOLDOWN
            return DwellState.COOLDOWN, 0.0

        return DwellState.IDLE, 0.0
