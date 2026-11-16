"""
Multi-Frame Neutral Pose Calibrator.
Implements robust statistical calibration with Median Absolute Deviation (MAD)
outlier filtering and stability thresholding.
"""

from dataclasses import dataclass, field
import math
from typing import List, Optional, Tuple


@dataclass
class CalibrationResult:
    success: bool
    yaw_baseline_deg: float = 0.0
    pitch_baseline_deg: float = 0.0
    roll_baseline_deg: float = 0.0
    yaw_std_deg: float = 0.0
    pitch_std_deg: float = 0.0
    total_frames: int = 0
    inlier_frames: int = 0
    error_message: Optional[str] = None


class NeutralPoseCalibrator:
    """
    Collects facial pose samples over a temporal window and computes
    a robust resting neutral baseline using MAD outlier filtering.
    """

    def __init__(
        self,
        duration_sec: float = 2.5,
        min_frames: int = 45,
        max_std_deg: float = 1.8,
    ) -> None:
        self.duration_sec = duration_sec
        self.min_frames = min_frames
        self.max_std_deg = max_std_deg

        self._samples_yaw: List[float] = []
        self._samples_pitch: List[float] = []
        self._samples_roll: List[float] = []
        self._timestamps: List[float] = []
        self._is_active: bool = False
        self._start_time: Optional[float] = None

    def start(self, current_time: float) -> None:
        """Starts a new calibration window."""
        self._samples_yaw.clear()
        self._samples_pitch.clear()
        self._samples_roll.clear()
        self._timestamps.clear()
        self._is_active = True
        self._start_time = current_time

    def cancel(self) -> None:
        """Cancels an ongoing calibration session."""
        self._is_active = False
        self._start_time = None
        self._samples_yaw.clear()
        self._samples_pitch.clear()
        self._samples_roll.clear()
        self._timestamps.clear()

    @property
    def is_active(self) -> bool:
        return self._is_active

    def add_sample(
        self,
        yaw_deg: float,
        pitch_deg: float,
        roll_deg: float,
        timestamp: float,
        confidence: float = 1.0,
    ) -> bool:
        """
        Adds a sample if calibration is active and confidence is sufficient.
        Returns True if calibration window has completed.
        """
        if not self._is_active or self._start_time is None:
            return False

        if confidence >= 0.65:
            self._samples_yaw.append(float(yaw_deg))
            self._samples_pitch.append(float(pitch_deg))
            self._samples_roll.append(float(roll_deg))
            self._timestamps.append(float(timestamp))

        elapsed = timestamp - self._start_time
        if elapsed >= self.duration_sec:
            self._is_active = False
            return True
        return False

    @property
    def progress(self) -> float:
        """Returns progress from 0.0 to 1.0."""
        if not self._is_active or not self._timestamps or self._start_time is None:
            return 0.0
        elapsed = self._timestamps[-1] - self._start_time
        return min(1.0, max(0.0, elapsed / self.duration_sec))

    @staticmethod
    def _compute_mad_inliers(samples: List[float]) -> Tuple[List[float], float, float]:
        """
        Computes median, MAD, and returns the filtered inlier list and standard deviation.
        """
        n = len(samples)
        if n == 0:
            return [], 0.0, 0.0

        sorted_s = sorted(samples)
        med = (sorted_s[n // 2 - 1] + sorted_s[n // 2]) / 2.0 if n % 2 == 0 else sorted_s[n // 2]

        abs_devs = sorted([abs(x - med) for x in samples])
        mad = (abs_devs[n // 2 - 1] + abs_devs[n // 2]) / 2.0 if n % 2 == 0 else abs_devs[n // 2]

        scale = 1.4826 * mad
        threshold = 2.5 * scale

        inliers = [x for x in samples if abs(x - med) <= threshold]
        if not inliers:
            inliers = samples

        mean = sum(inliers) / len(inliers)
        variance = sum((x - mean) ** 2 for x in inliers) / len(inliers)
        std_dev = math.sqrt(variance)

        return inliers, mean, std_dev

    def finalize(self) -> CalibrationResult:
        """
        Analyzes the collected samples, filters outliers, verifies stability,
        and returns the final baseline result.
        """
        self._is_active = False
        total = len(self._samples_yaw)

        if total < self.min_frames:
            return CalibrationResult(
                success=False,
                total_frames=total,
                error_message=f"Insufficient frames captured ({total}/{self.min_frames}). Please retry while holding steady.",
            )

        yaw_inliers, yaw_baseline, yaw_std = self._compute_mad_inliers(self._samples_yaw)
        pitch_inliers, pitch_baseline, pitch_std = self._compute_mad_inliers(self._samples_pitch)
        roll_inliers, roll_baseline, roll_std = self._compute_mad_inliers(self._samples_roll)

        # Check stability against maximum allowed motion threshold
        if yaw_std > self.max_std_deg or pitch_std > self.max_std_deg:
            return CalibrationResult(
                success=False,
                yaw_baseline_deg=yaw_baseline,
                pitch_baseline_deg=pitch_baseline,
                roll_baseline_deg=roll_baseline,
                yaw_std_deg=yaw_std,
                pitch_std_deg=pitch_std,
                total_frames=total,
                inlier_frames=min(len(yaw_inliers), len(pitch_inliers)),
                error_message=(
                    f"Excessive head movement detected (yaw std: {yaw_std:.2f}°, "
                    f"pitch std: {pitch_std:.2f}°, limit: {self.max_std_deg}°). "
                    "Please hold your head still and retry."
                ),
            )

        return CalibrationResult(
            success=True,
            yaw_baseline_deg=yaw_baseline,
            pitch_baseline_deg=pitch_baseline,
            roll_baseline_deg=roll_baseline,
            yaw_std_deg=yaw_std,
            pitch_std_deg=pitch_std,
            total_frames=total,
            inlier_frames=min(len(yaw_inliers), len(pitch_inliers)),
        )
