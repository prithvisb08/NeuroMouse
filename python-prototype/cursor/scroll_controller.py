"""
Continuous Pitch-Tilt Scroll Controller.
Translates sustained vertical head pitch deflections into smooth macOS scroll wheel events.
"""

import math
from typing import Callable, Optional


class ScrollController:
    """
    Manages pitch-tilt scroll velocity curves and injection throttling.
    """

    def __init__(
        self,
        scroll_threshold_deg: float = 6.0,
        scroll_speed_multiplier: float = 1.0,
        on_scroll: Optional[Callable[[int], None]] = None,
    ) -> None:
        self.scroll_threshold = scroll_threshold_deg
        self.speed_multiplier = scroll_speed_multiplier
        self.on_scroll = on_scroll

        self._last_scroll_time: float = 0.0
        self._scroll_interval: float = 0.05  # 20 Hz scroll pulse

    def update(
        self,
        delta_pitch_deg: float,
        timestamp: float,
        is_dwelling: bool = False,
    ) -> Optional[int]:
        """
        Calculates scroll impulse and dispatches event if threshold is exceeded.
        """
        # Suppress scrolling during dwell countdown
        if is_dwelling:
            return None

        abs_pitch = abs(delta_pitch_deg)
        if abs_pitch <= self.scroll_threshold:
            return None

        if (timestamp - self._last_scroll_time) < self._scroll_interval:
            return None

        excess = abs_pitch - self.scroll_threshold
        # Non-linear acceleration curve
        magnitude = (excess ** 1.4) * 2.5 * self.speed_multiplier
        sign = 1.0 if delta_pitch_deg < 0 else -1.0  # Up tilt scrolls up (+), down tilt scrolls down (-)
        scroll_units = int(sign * magnitude)

        if scroll_units != 0:
            self._last_scroll_time = timestamp
            if self.on_scroll:
                self.on_scroll(scroll_units)
            return scroll_units

        return None
