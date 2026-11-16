"""
Spatial Cursor Overlay & HUD Renderer.
Renders visual feedback including the live circular countdown ring around the cursor,
stability bounds, and gesture trigger indicators.
"""

import math
from typing import Optional, Tuple
import numpy as np


class SpatialCursorOverlay:
    """
    Draws the dwell ring and spatial feedback HUD.
    """

    def __init__(self, dwell_radius_px: float = 18.0) -> None:
        self.dwell_radius_px = dwell_radius_px

    def draw_dwell_ring_on_frame(
        self,
        frame_bgr: np.ndarray,
        center_x: int,
        center_y: int,
        progress: float,
        is_dwelling: bool,
        is_right_click_armed: bool = False,
    ) -> np.ndarray:
        """
        Draws the dwell countdown circle and progress arc onto a frame.
        """
        try:
            import cv2
        except ImportError:
            return frame_bgr

        if not is_dwelling and progress <= 0.0:
            return frame_bgr

        radius = int(self.dwell_radius_px)
        color_bg = (80, 80, 80)
        color_fg = (0, 165, 255) if is_right_click_armed else (0, 255, 128)

        # Draw outer thin guide circle
        cv2.circle(frame_bgr, (center_x, center_y), radius, color_bg, 1, cv2.LINE_AA)

        # Draw filled radial arc indicating progress
        angle = int(360.0 * min(1.0, max(0.0, progress)))
        if angle > 0:
            cv2.ellipse(
                frame_bgr,
                (center_x, center_y),
                (radius, radius),
                -90,  # Start at 12 o'clock
                0,
                angle,
                color_fg,
                3,
                cv2.LINE_AA,
            )

        return frame_bgr
