"""
Nod Gesture Detector.
Detects a rapid pitch-down-and-return impulse within a 450 ms window
while maintaining lateral yaw stability.
"""

from enum import Enum
from typing import Callable, Optional


class NodState(str, Enum):
    IDLE = "idle"
    PITCH_DOWN = "pitch_down"
    REBOUNDING = "rebounding"


class NodDetector:
    """
    State machine identifying deliberate head-nod gestures.
    """

    def __init__(
        self,
        pitch_threshold_deg: float = 4.5,
        max_duration_sec: float = 0.45,
        max_yaw_dev_deg: float = 2.0,
        on_nod: Optional[Callable[[], None]] = None,
    ) -> None:
        self.pitch_threshold = pitch_threshold_deg
        self.max_duration = max_duration_sec
        self.max_yaw_dev = max_yaw_dev_deg
        self.on_nod = on_nod

        self.state: NodState = NodState.IDLE
        self.start_time: float = 0.0
        self.peak_pitch: float = 0.0
        self.initial_yaw: float = 0.0
        self.last_nod_time: float = -10.0

    def reset(self) -> None:
        self.state = NodState.IDLE
        self.start_time = 0.0
        self.peak_pitch = 0.0

    def update(
        self,
        delta_yaw_deg: float,
        delta_pitch_deg: float,
        timestamp: float,
        is_dwelling: bool = False,
    ) -> bool:
        """
        Processes angular offsets and fires on_nod if a valid nod impulse occurs.
        Suppressed if cursor is currently dwelling.
        """
        # Cross-firing prevention: suppress nod during dwell countdown
        if is_dwelling:
            self.reset()
            return False

        # Refractory cooldown between nods (800 ms)
        if timestamp - self.last_nod_time < 0.8:
            return False

        # Check yaw stability
        if abs(delta_yaw_deg) > self.max_yaw_dev:
            self.reset()
            return False

        if self.state == NodState.IDLE:
            # Positive delta_pitch is downwards tilt
            if delta_pitch_deg >= self.pitch_threshold:
                self.state = NodState.PITCH_DOWN
                self.start_time = timestamp
                self.peak_pitch = delta_pitch_deg
                self.initial_yaw = delta_yaw_deg

        elif self.state == NodState.PITCH_DOWN:
            elapsed = timestamp - self.start_time
            if elapsed > self.max_duration:
                self.reset()
                return False

            if delta_pitch_deg > self.peak_pitch:
                self.peak_pitch = delta_pitch_deg

            # Check for rebound back towards neutral (<= 1.5 degrees)
            if delta_pitch_deg <= 1.5 and self.peak_pitch >= self.pitch_threshold:
                # Valid nod gesture detected!
                self.last_nod_time = timestamp
                self.reset()
                if self.on_nod:
                    self.on_nod()
                return True

        return False
