"""
Camera Manager.
Manages webcam capture, zero-copy buffer handoff, horizontal mirroring,
and synthetic frame injection for headless testing.
"""

import sys
import time
from typing import Optional, Tuple
import numpy as np


class CameraManager:
    """
    Manages webcam capture lifecycle with horizontal mirroring
    and synthetic frame injection for automated testing.
    """

    def __init__(
        self,
        camera_index: int = 0,
        width: int = 640,
        height: int = 480,
        target_fps: int = 30,
        mirror_horizontal: bool = True,
    ) -> None:
        self.camera_index = camera_index
        self.width = width
        self.height = height
        self.target_fps = target_fps
        self.mirror_h = mirror_horizontal

        self._cap = None
        self._is_opened = False
        self._has_cv2 = False

        try:
            import cv2
            self._cv2 = cv2
            self._has_cv2 = True
        except ImportError:
            self._cv2 = None

    def open(self) -> bool:
        """Opens the camera capture device."""
        if not self._has_cv2:
            return False

        try:
            if sys.platform == "win32":
                # Use DirectShow on Windows for low-latency initialization
                self._cap = self._cv2.VideoCapture(self.camera_index, self._cv2.CAP_DSHOW)
                if not self._cap.isOpened():
                    self._cap = self._cv2.VideoCapture(self.camera_index)
            else:
                self._cap = self._cv2.VideoCapture(self.camera_index)

            if not self._cap.isOpened():
                self._is_opened = False
                return False

            self._cap.set(self._cv2.CAP_PROP_FRAME_WIDTH, self.width)
            self._cap.set(self._cv2.CAP_PROP_FRAME_HEIGHT, self.height)
            self._cap.set(self._cv2.CAP_PROP_FPS, self.target_fps)
            self._is_opened = True
            return True
        except Exception:
            self._is_opened = False
            return False

    def close(self) -> None:
        """Releases the camera device."""
        if self._cap is not None:
            try:
                self._cap.release()
            except Exception:
                pass
            self._cap = None
        self._is_opened = False

    @property
    def is_opened(self) -> bool:
        return self._is_opened

    def read_frame(self) -> Tuple[bool, Optional[np.ndarray], float]:
        """
        Reads a frame from the camera, mirrors horizontally, and returns:
        (success, frame_rgb, timestamp).
        """
        timestamp = time.monotonic()

        if not self._is_opened or self._cap is None:
            return False, None, timestamp

        ret, frame_bgr = self._cap.read()
        if not ret or frame_bgr is None:
            return False, None, timestamp

        # Apply horizontal selfie mirror
        if self.mirror_h:
            frame_bgr = self._cv2.flip(frame_bgr, 1)

        frame_rgb = self._cv2.cvtColor(frame_bgr, self._cv2.COLOR_BGR2RGB)
        return True, frame_rgb, timestamp

    def create_synthetic_frame(
        self,
        color: Tuple[int, int, int] = (40, 40, 40),
    ) -> Tuple[bool, np.ndarray, float]:
        """
        Generates a synthetic blank test frame for headless test suites.
        """
        timestamp = time.monotonic()
        frame = np.full((self.height, self.width, 3), color, dtype=np.uint8)
        return True, frame, timestamp
