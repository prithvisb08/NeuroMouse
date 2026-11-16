"""
Face Landmarks Extractor.
Extracts normalized and pixel-space landmarks for the Rigid Upper Craniofacial Triad
and eye contours using MediaPipe Face Landmarker Tasks API.
"""

from dataclasses import dataclass
import os
from typing import List, Optional, Tuple
import numpy as np

from .head_pose import UPPER_CRANIOFACIAL_INDICES


# Eyelid landmark indices for EAR computation
LEFT_EYE_INDICES = [33, 160, 158, 133, 153, 144]
RIGHT_EYE_INDICES = [362, 385, 387, 263, 373, 380]


@dataclass
class FaceLandmarksResult:
    detected: bool
    confidence: float = 0.0
    upper_craniofacial_2d: Optional[np.ndarray] = None  # shape (8, 2) in pixels
    left_eye_points: Optional[List[Tuple[float, float]]] = None
    right_eye_points: Optional[List[Tuple[float, float]]] = None
    all_landmarks_normalized: Optional[np.ndarray] = None  # shape (N, 3)


class FaceLandmarksExtractor:
    """
    Wraps MediaPipe Face Landmarker Tasks API with local model loading.
    """

    def __init__(
        self,
        model_path: Optional[str] = None,
        confidence_threshold: float = 0.65,
    ) -> None:
        self.confidence_threshold = confidence_threshold

        if model_path is None:
            # Default to vendored model asset
            current_dir = os.path.dirname(os.path.abspath(__file__))
            model_path = os.path.join(current_dir, "..", "models", "face_landmarker.task")

        self.model_path = os.path.abspath(model_path)
        self._landmarker = None
        self._initialized = False

        self._init_mediapipe()

    def _init_mediapipe(self) -> None:
        """Initializes the MediaPipe Tasks Face Landmarker if installed and model exists."""
        if not os.path.exists(self.model_path):
            try:
                os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
                import urllib.request
                print(f"[INFO] Downloading MediaPipe face_landmarker.task model to {self.model_path}...")
                model_url = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
                urllib.request.urlretrieve(model_url, self.model_path)
                print("[INFO] MediaPipe model downloaded successfully.")
            except Exception as e:
                print(f"[WARN] Could not automatically download model: {e}")
                return

        try:
            import mediapipe as mp
            from mediapipe.tasks import python as mp_python
            from mediapipe.tasks.python import vision

            base_options = mp_python.BaseOptions(model_asset_path=self.model_path)
            options = vision.FaceLandmarkerOptions(
                base_options=base_options,
                running_mode=vision.RunningMode.IMAGE,
                num_faces=1,
                min_face_detection_confidence=self.confidence_threshold,
                min_face_presence_confidence=self.confidence_threshold,
                min_tracking_confidence=self.confidence_threshold,
                output_face_blendshapes=False,
                output_facial_transformation_matrixes=False,
            )
            self._landmarker = vision.FaceLandmarker.create_from_options(options)
            self._mp = mp
            self._initialized = True
        except Exception:
            self._landmarker = None
            self._initialized = False

    @property
    def is_ready(self) -> bool:
        return self._initialized and (self._landmarker is not None)

    def process_frame(
        self,
        frame_rgb: np.ndarray,
        width: int,
        height: int,
    ) -> FaceLandmarksResult:
        """
        Extracts craniofacial landmarks from an RGB frame.

        Args:
            frame_rgb: numpy array (H, W, 3) in uint8 RGB format.
            width: Image width in pixels.
            height: Image height in pixels.

        Returns:
            FaceLandmarksResult with upper craniofacial 2D points and eye contours.
        """
        if not self.is_ready or frame_rgb is None:
            return FaceLandmarksResult(detected=False)

        try:
            mp_image = self._mp.Image(
                image_format=self._mp.ImageFormat.SRGB,
                data=frame_rgb,
            )
            detection_result = self._landmarker.detect(mp_image)

            if not detection_result.face_landmarks:
                return FaceLandmarksResult(detected=False)

            face = detection_result.face_landmarks[0]
            num_pts = len(face)

            # Convert to numpy array of normalized (x, y, z)
            norm_pts = np.zeros((num_pts, 3), dtype=np.float64)
            for idx, lm in enumerate(face):
                norm_pts[idx] = [lm.x, lm.y, lm.z]

            # Extract upper craniofacial triad in pixel space
            upper_pts = np.zeros((len(UPPER_CRANIOFACIAL_INDICES), 2), dtype=np.float64)
            for i, idx in enumerate(UPPER_CRANIOFACIAL_INDICES):
                upper_pts[i] = [norm_pts[idx, 0] * width, norm_pts[idx, 1] * height]

            # Extract eye contours for EAR
            left_eye = [(norm_pts[i, 0] * width, norm_pts[i, 1] * height) for i in LEFT_EYE_INDICES]
            right_eye = [(norm_pts[i, 0] * width, norm_pts[i, 1] * height) for i in RIGHT_EYE_INDICES]

            return FaceLandmarksResult(
                detected=True,
                confidence=1.0,
                upper_craniofacial_2d=upper_pts,
                left_eye_points=left_eye,
                right_eye_points=right_eye,
                all_landmarks_normalized=norm_pts,
            )
        except Exception:
            return FaceLandmarksResult(detected=False)
