"""
Movement Mapper & Spatial Coordinate Engine.
Maps angular head deviations (yaw, pitch, roll) to macOS screen coordinates.
Implements roll-decomposition, dead-zone, 1€ filtering, and dual-mode control.
"""

from enum import Enum
import math
from typing import Optional, Tuple

from .dead_zone import apply_dead_zone
from .one_euro_filter import OneEuroFilter2D


class MappingMode(str, Enum):
    DIRECT_ABSOLUTE = "direct_absolute"
    HYBRID_ABSOLUTE = "hybrid_absolute"


class MovementMapper:
    """
    Translates calibrated, roll-compensated head angles into absolute/hybrid screen cursor points.
    """

    def __init__(
        self,
        screen_width: float = 1920.0,
        screen_height: float = 1080.0,
        yaw_range_deg: float = 15.0,
        pitch_range_deg: float = 10.0,
        horizontal_dead_zone_deg: float = 1.2,
        vertical_dead_zone_deg: float = 1.2,
        horizontal_sensitivity: float = 1.0,
        vertical_sensitivity: float = 1.0,
        invert_horizontal: bool = False,
        invert_vertical: bool = False,
        mapping_mode: MappingMode = MappingMode.HYBRID_ABSOLUTE,
        one_euro_min_cutoff: float = 1.0,
        one_euro_beta: float = 0.04,
        one_euro_d_cutoff: float = 1.0,
        k_parallax: float = 0.65,
    ) -> None:
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.yaw_range_deg = yaw_range_deg
        self.pitch_range_deg = pitch_range_deg
        self.h_dead_zone = horizontal_dead_zone_deg
        self.v_dead_zone = vertical_dead_zone_deg
        self.h_sensitivity = horizontal_sensitivity
        self.v_sensitivity = vertical_sensitivity
        self.invert_h = invert_horizontal
        self.invert_v = invert_vertical
        self.mapping_mode = mapping_mode
        self.k_parallax = k_parallax

        self.filter = OneEuroFilter2D(
            min_cutoff=one_euro_min_cutoff,
            beta=one_euro_beta,
            d_cutoff=one_euro_d_cutoff,
        )

        # Baseline resting angles
        self.baseline_yaw: float = 0.0
        self.baseline_pitch: float = 0.0
        self.baseline_roll: float = 0.0
        self.baseline_norm_x: float = 0.5
        self.baseline_norm_y: float = 0.5

        # Edge panning persistent state for hybrid mode
        self._current_screen_x: float = screen_width / 2.0
        self._current_screen_y: float = screen_height / 2.0

        # UI gravity damping multiplier
        self.gravity_damping: float = 1.0

    def set_display_bounds(self, width: float, height: float) -> None:
        """Updates active screen resolution bounds."""
        self.screen_width = max(100.0, width)
        self.screen_height = max(100.0, height)

    def set_baseline(self, yaw: float, pitch: float, roll: float) -> None:
        """Sets the neutral reference baseline."""
        self.baseline_yaw = float(yaw)
        self.baseline_pitch = float(pitch)
        self.baseline_roll = float(roll)
        self.filter.reset()
        self._current_screen_x = self.screen_width / 2.0
        self._current_screen_y = self.screen_height / 2.0

    def set_headphone_baseline(self, norm_x: float = 0.5, norm_y: float = 0.5) -> None:
        """Sets the neutral center baseline for headphone tracking."""
        self.baseline_norm_x = float(norm_x)
        self.baseline_norm_y = float(norm_y)
        self.filter.reset()
        self._current_screen_x = self.screen_width / 2.0
        self._current_screen_y = self.screen_height / 2.0

    def process_headphone(
        self,
        norm_x: float,
        norm_y: float,
        timestamp: float,
    ) -> Tuple[float, float]:
        """
        Maps normalized camera headphone coordinates (0..1, 0..1) to screen cursor position.
        Applies deadzone, 1 Euro adaptive filtering, and sensitivity.
        """
        eff_x = (1.0 - norm_x) if self.invert_h else norm_x
        eff_y = (1.0 - norm_y) if self.invert_v else norm_y

        delta_x = eff_x - self.baseline_norm_x
        delta_y = eff_y - self.baseline_norm_y

        # Deadzone to eliminate hand tremor (1.5% deadzone)
        dz_x = apply_dead_zone(delta_x, threshold=0.015)
        dz_y = apply_dead_zone(delta_y, threshold=0.015)

        gain_x = self.h_sensitivity * self.gravity_damping * 2.5
        gain_y = self.v_sensitivity * self.gravity_damping * 2.5

        scaled_x = dz_x * gain_x
        scaled_y = dz_y * gain_y

        filt_x, filt_y = self.filter.filter(scaled_x, scaled_y, timestamp)

        target_norm_x = max(0.0, min(1.0, 0.5 + filt_x))
        target_norm_y = max(0.0, min(1.0, 0.5 + filt_y))

        self._current_screen_x = target_norm_x * self.screen_width
        self._current_screen_y = target_norm_y * self.screen_height

        return self._current_screen_x, self._current_screen_y

    def apply_parallax_compensation(
        self,
        yaw_deg: float,
        pitch_deg: float,
        tx_mm: float,
        ty_mm: float,
        tz_mm: float,
    ) -> Tuple[float, float]:
        """
        Compensates for body lateral translation when using hybrid position/rotation signals.
        """
        if abs(tz_mm) < 1e-4:
            return yaw_deg, pitch_deg

        ang_x_deg = math.degrees(math.atan2(tx_mm, tz_mm))
        ang_y_deg = math.degrees(math.atan2(ty_mm, tz_mm))

        yaw_corr = yaw_deg - self.k_parallax * ang_x_deg
        pitch_corr = pitch_deg - self.k_parallax * ang_y_deg
        return yaw_corr, pitch_corr

    def project_roll_horizon(
        self,
        delta_yaw: float,
        delta_pitch: float,
        baseline_roll_deg: float,
    ) -> Tuple[float, float]:
        """
        Rotates angular deviations by the negative baseline roll angle
        so horizontal sweeps stay along the user's natural horizon frame.
        """
        phi_rad = math.radians(-baseline_roll_deg)
        cos_p = math.cos(phi_rad)
        sin_p = math.sin(phi_rad)

        proj_yaw = cos_p * delta_yaw - sin_p * delta_pitch
        proj_pitch = sin_p * delta_yaw + cos_p * delta_pitch
        return proj_yaw, proj_pitch

    def process(
        self,
        raw_yaw: float,
        raw_pitch: float,
        raw_roll: float,
        timestamp: float,
        tx_mm: float = 0.0,
        ty_mm: float = 0.0,
        tz_mm: float = 500.0,
        is_hybrid_pose: bool = False,
    ) -> Tuple[float, float]:
        """
        Processes a raw head pose observation and returns clamped macOS screen coordinates (x, y).
        """
        # 1. Translation / Parallax Compensation (if hybrid)
        if is_hybrid_pose:
            yaw, pitch = self.apply_parallax_compensation(raw_yaw, raw_pitch, tx_mm, ty_mm, tz_mm)
        else:
            yaw, pitch = raw_yaw, raw_pitch

        # 2. Subtract neutral baseline
        delta_yaw = yaw - self.baseline_yaw
        delta_pitch = pitch - self.baseline_pitch

        # 3. Roll horizon decomposition
        proj_yaw, proj_pitch = self.project_roll_horizon(delta_yaw, delta_pitch, self.baseline_roll)

        # 4. Inversion flags
        if self.invert_h:
            proj_yaw = -proj_yaw
        if self.invert_v:
            proj_pitch = -proj_pitch

        # 5. Smooth Dead-Zone filter
        dz_yaw = apply_dead_zone(proj_yaw, threshold=self.h_dead_zone)
        dz_pitch = apply_dead_zone(proj_pitch, threshold=self.v_dead_zone)

        # 6. Apply sensitivity and UI gravity damping
        effective_h_gain = self.h_sensitivity * self.gravity_damping
        effective_v_gain = self.v_sensitivity * self.gravity_damping

        scaled_yaw = dz_yaw * effective_h_gain
        scaled_pitch = dz_pitch * effective_v_gain

        # 7. One Euro Filter
        filt_yaw, filt_pitch = self.filter.filter(scaled_yaw, scaled_pitch, timestamp)

        # 8. Screen Coordinate Mapping
        norm_x = (filt_yaw / (2.0 * self.yaw_range_deg)) + 0.5
        norm_y = (filt_pitch / (2.0 * self.pitch_range_deg)) + 0.5

        if self.mapping_mode == MappingMode.DIRECT_ABSOLUTE:
            target_x = norm_x * self.screen_width
            target_y = norm_y * self.screen_height
            self._current_screen_x = max(0.0, min(self.screen_width, target_x))
            self._current_screen_y = max(0.0, min(self.screen_height, target_y))
        else:
            # Hybrid Mode: Central 80% is absolute; outer 10% bezel provides smooth auto-pan
            pan_speed = 12.0  # px per frame at edge
            pan_dx = 0.0
            pan_dy = 0.0

            if norm_x < 0.10:
                pan_dx = -pan_speed * (0.10 - norm_x) / 0.10
            elif norm_x > 0.90:
                pan_dx = pan_speed * (norm_x - 0.90) / 0.10

            if norm_y < 0.10:
                pan_dy = -pan_speed * (0.10 - norm_y) / 0.10
            elif norm_y > 0.90:
                pan_dy = pan_speed * (norm_y - 0.90) / 0.10

            # Absolute center component
            center_x = norm_x * self.screen_width
            center_y = norm_y * self.screen_height

            self._current_screen_x = max(0.0, min(self.screen_width, center_x + pan_dx))
            self._current_screen_y = max(0.0, min(self.screen_height, center_y + pan_dy))

        return self._current_screen_x, self._current_screen_y
