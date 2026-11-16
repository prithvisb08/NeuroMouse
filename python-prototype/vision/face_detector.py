"""
High-Level Face & Pose Detection Pipeline.
Combines landmark extraction, PnP pose recovery, re-entry stabilization,
and safety freezing on face loss.
"""

from dataclasses import dataclass
import time
from typing import Optional, Tuple
import numpy as np

from .face_landmarks import FaceLandmarksExtractor, FaceLandmarksResult
from .head_pose import CraniofacialPoseEstimator


@dataclass
class HeadPoseObservation:
    is_valid: bool
    confidence: float = 0.0
    yaw_deg: float = 0.0
    pitch_deg: float = 0.0
    roll_deg: float = 0.0
    tx_mm: float = 0.0
    ty_mm: float = 0.0
    tz_mm: float = 500.0
    timestamp: float = 0.0
    landmarks_result: Optional[FaceLandmarksResult] = None


class FacePosePipeline:
    """
    Complete computer vision pipeline managing camera frame inference,
    re-entry stability gating, and smooth interpolation.
    """

    def __init__(
        self,
        camera_width: int = 640,
        camera_height: int = 480,
        confidence_threshold: float = 0.65,
        reentry_stable_frames: int = 10,
        reentry_blend_duration_sec: float = 0.3,
        model_path: Optional[str] = None,
    ) -> None:
        self.width = camera_width
        self.height = camera_height
        self.confidence_threshold = confidence_threshold
        self.required_stable_frames = reentry_stable_frames
        self.blend_duration = reentry_blend_duration_sec

        self.landmarks_extractor = FaceLandmarksExtractor(
            model_path=model_path,
            confidence_threshold=confidence_threshold,
        )
        self.pose_estimator = CraniofacialPoseEstimator(
            camera_width=camera_width,
            camera_height=camera_height,
        )

        # State tracking
        self._consecutive_valid_frames: int = 0
        self._is_face_locked: bool = False
        self._reentry_start_time: Optional[float] = None

        self._last_valid_yaw: float = 0.0
        self._last_valid_pitch: float = 0.0
        self._last_valid_roll: float = 0.0

    @property
    def is_face_locked(self) -> bool:
        return self._is_face_locked

    def process_frame(
        self,
        frame_rgb: np.ndarray,
        timestamp: float,
    ) -> HeadPoseObservation:
        """
        Processes an RGB frame and returns filtered 3D head pose observation.
        """
        lm_result = self.landmarks_extractor.process_frame(frame_rgb, self.width, self.height)

        if not lm_result.detected or lm_result.upper_craniofacial_2d is None:
            # Face Lost: instantly reset stability counter and freeze
            self._consecutive_valid_frames = 0
            self._is_face_locked = False
            self._reentry_start_time = None
            return HeadPoseObservation(
                is_valid=False,
                confidence=0.0,
                timestamp=timestamp,
                landmarks_result=lm_result,
            )

        # Solve 3D Pose
        yaw, pitch, roll, rmat, tvec = self.pose_estimator.estimate_pose(
            lm_result.upper_craniofacial_2d
        )

        tx = float(tvec[0, 0])
        ty = float(tvec[1, 0])
        tz = float(tvec[2, 0])

        self._consecutive_valid_frames += 1

        # Check re-entry stabilization criteria
        if not self._is_face_locked:
            if self._consecutive_valid_frames >= self.required_stable_frames:
                self._is_face_locked = True
                self._reentry_start_time = timestamp
                self._last_valid_yaw = yaw
                self._last_valid_pitch = pitch
                self._last_valid_roll = roll
            else:
                # Still stabilizing: suppress motion output
                return HeadPoseObservation(
                    is_valid=False,
                    confidence=0.5,
                    timestamp=timestamp,
                    landmarks_result=lm_result,
                )

        # Smooth re-entry blending over 300 ms to avoid teleportation jump
        if self._reentry_start_time is not None:
            elapsed = timestamp - self._reentry_start_time
            if elapsed < self.blend_duration:
                w = min(1.0, max(0.0, elapsed / self.blend_duration))
                yaw = (1.0 - w) * self._last_valid_yaw + w * yaw
                pitch = (1.0 - w) * self._last_valid_pitch + w * pitch
                roll = (1.0 - w) * self._last_valid_roll + w * roll
            else:
                self._reentry_start_time = None

        self._last_valid_yaw = yaw
        self._last_valid_pitch = pitch
        self._last_valid_roll = roll

        return HeadPoseObservation(
            is_valid=True,
            confidence=lm_result.confidence,
            yaw_deg=yaw,
            pitch_deg=pitch,
            roll_deg=roll,
            tx_mm=tx,
            ty_mm=ty,
            tz_mm=tz,
            timestamp=timestamp,
            landmarks_result=lm_result,
        )
