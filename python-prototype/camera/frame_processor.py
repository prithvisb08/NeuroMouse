"""
Frame Processor & Telemetry Profiler.
Measures real-time FPS, frame processing latency, and manages privacy shutter blanking.
"""

import time
from typing import Optional, Tuple
import numpy as np


class FrameProcessor:
    """
    Computes frame processing performance telemetry (FPS, latency)
    and enforces Privacy Shutter blanking.
    """

    def __init__(self, privacy_shutter_enabled: bool = False) -> None:
        self.privacy_shutter = privacy_shutter_enabled

        self._last_frame_time: Optional[float] = None
        self._fps: float = 30.0
        self._latency_ms: float = 0.0
        self._alpha_smooth: float = 0.1

    @property
    def fps(self) -> float:
        return self._fps

    @property
    def latency_ms(self) -> float:
        return self._latency_ms

    def start_timing(self) -> float:
        return time.monotonic()

    def stop_timing(self, start_t: float) -> float:
        now = time.monotonic()
        dt_frame = (now - self._last_frame_time) if self._last_frame_time is not None else (1.0 / 30.0)
        self._last_frame_time = now

        if dt_frame > 0:
            instant_fps = 1.0 / dt_frame
            self._fps = (1.0 - self._alpha_smooth) * self._fps + self._alpha_smooth * instant_fps

        instant_latency = (now - start_t) * 1000.0
        self._latency_ms = (1.0 - self._alpha_smooth) * self._latency_ms + self._alpha_smooth * instant_latency
        return self._latency_ms

    def prepare_preview_frame(self, frame_rgb: np.ndarray) -> np.ndarray:
        """
        Applies privacy shutter if enabled, otherwise returns the frame for rendering.
        """
        if self.privacy_shutter or frame_rgb is None:
            # Blank out visual pixels for privacy
            h, w = (480, 640) if frame_rgb is None else frame_rgb.shape[:2]
            return np.zeros((h, w, 3), dtype=np.uint8)
        return frame_rgb
