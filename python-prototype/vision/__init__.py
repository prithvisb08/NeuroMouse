"""
Vision Package for HeadMotion Mouse.
Provides MediaPipe landmark extraction, craniofacial 3D pose estimation, and face pipeline.
"""

from .head_pose import CraniofacialPoseEstimator, CANONICAL_3D_POINTS, UPPER_CRANIOFACIAL_INDICES
from .face_landmarks import FaceLandmarksExtractor, FaceLandmarksResult, LEFT_EYE_INDICES, RIGHT_EYE_INDICES
from .face_detector import FacePosePipeline, HeadPoseObservation
from .headphone_tracker import HeadphoneVisualTracker, HeadphoneObservation

__all__ = [
    "CraniofacialPoseEstimator",
    "CANONICAL_3D_POINTS",
    "UPPER_CRANIOFACIAL_INDICES",
    "FaceLandmarksExtractor",
    "FaceLandmarksResult",
    "LEFT_EYE_INDICES",
    "RIGHT_EYE_INDICES",
    "FacePosePipeline",
    "HeadPoseObservation",
    "HeadphoneVisualTracker",
    "HeadphoneObservation",
]
