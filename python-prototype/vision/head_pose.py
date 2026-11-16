"""
Speech-Immune & Headphone-Immune 3D Craniofacial Pose Estimator.
Recovers 3D rotation (yaw, pitch, roll) and translation from the Rigid Upper Craniofacial Triad.
Completely ignores lower jaw/chin (immune to speech movement) and ears/temple contours
(immune to occlusion from JBL Live 770NC over-ear headphones).
"""

import math
from typing import Dict, List, Optional, Tuple
import numpy as np


# Canonical 3D Metric Model (mm) for the Rigid Upper Craniofacial Anchor Set
# Origin at Pronasale (nose tip)
CANONICAL_3D_POINTS = np.array([
    [0.0, 0.0, 0.0],       # 0: Pronasale (Nose Tip)
    [0.0, 38.0, -12.0],     # 1: Glabella / Nasion (Between Eyebrows)
    [-22.0, 26.0, -28.0],   # 2: Left Endocanthion (Inner Canthus)
    [22.0, 26.0, -28.0],    # 3: Right Endocanthion (Inner Canthus)
    [-55.0, 28.0, -42.0],   # 4: Left Exocanthion (Outer Canthus)
    [55.0, 28.0, -42.0],    # 5: Right Exocanthion (Outer Canthus)
    [-38.0, 48.0, -25.0],   # 6: Left Supraorbital (Mid-Eyebrow)
    [38.0, 48.0, -25.0],    # 7: Right Supraorbital (Mid-Eyebrow)
], dtype=np.float64)

# Corresponding MediaPipe landmark indices
UPPER_CRANIOFACIAL_INDICES = [1, 168, 133, 362, 33, 263, 105, 334]


class CraniofacialPoseEstimator:
    """
    Solves 3D pose using upper craniofacial landmarks with Levenberg-Marquardt PnP
    and intrinsic Y-X-Z Euler decomposition.
    """

    def __init__(
        self,
        camera_width: int = 640,
        camera_height: int = 480,
    ) -> None:
        self.width = camera_width
        self.height = camera_height

        # Approximate pinhole camera intrinsics
        focal_length = float(camera_width)
        center_x = float(camera_width) / 2.0
        center_y = float(camera_height) / 2.0

        self.camera_matrix = np.array([
            [focal_length, 0.0, center_x],
            [0.0, focal_length, center_y],
            [0.0, 0.0, 1.0],
        ], dtype=np.float64)

        self.dist_coeffs = np.zeros((4, 1), dtype=np.float64)

        # Check if cv2 is available
        self._has_cv2 = False
        try:
            import cv2
            self._cv2 = cv2
            self._has_cv2 = True
        except ImportError:
            self._cv2 = None

    def estimate_pose(
        self,
        points_2d: np.ndarray,
    ) -> Tuple[float, float, float, np.ndarray, np.ndarray]:
        """
        Solves 3D pose from 2D pixel coordinates of the 8 canonical upper facial landmarks.

        Args:
            points_2d: Array of shape (8, 2) in image pixel coordinates.

        Returns:
            Tuple of (yaw_deg, pitch_deg, roll_deg, rotation_matrix, translation_vector).
        """
        points_2d = np.ascontiguousarray(points_2d, dtype=np.float64)

        if self._has_cv2:
            success, rvec, tvec = self._cv2.solvePnP(
                CANONICAL_3D_POINTS,
                points_2d,
                self.camera_matrix,
                self.dist_coeffs,
                flags=self._cv2.SOLVEPNP_ITERATIVE,
            )
            if not success:
                return 0.0, 0.0, 0.0, np.eye(3), np.zeros((3, 1))

            rmat, _ = self._cv2.Rodrigues(rvec)
        else:
            # Pure NumPy Orthogonal Procrustes fallback for environments without cv2
            rmat, tvec = self._solve_pnp_numpy(points_2d)

        yaw, pitch, roll = self.rotation_matrix_to_euler_yxz(rmat)
        return yaw, pitch, roll, rmat, tvec

    def _solve_pnp_numpy(self, points_2d: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        """
        Closed-form affine / Orthogonal Procrustes estimator for headless/test environments.
        """
        pts_3d = CANONICAL_3D_POINTS
        centroid_3d = np.mean(pts_3d, axis=0)
        centroid_2d = np.mean(points_2d, axis=0)

        p3 = pts_3d - centroid_3d
        p2 = points_2d - centroid_2d

        # Estimate scale
        scale = np.mean(np.linalg.norm(p2, axis=1)) / (np.mean(np.linalg.norm(p3[:, :2], axis=1)) + 1e-6)

        # Build 3D pseudo points
        p2_3d = np.zeros_like(pts_3d)
        p2_3d[:, 0] = p2[:, 0] / scale
        p2_3d[:, 1] = p2[:, 1] / scale
        p2_3d[:, 2] = pts_3d[:, 2]  # depth prior

        # SVD rotation
        H = p3.T @ p2_3d
        U, S, Vt = np.linalg.svd(H)
        R = Vt.T @ U.T

        if np.linalg.det(R) < 0:
            Vt[2, :] *= -1
            R = Vt.T @ U.T

        tz = float(self.camera_matrix[0, 0]) / max(scale, 1e-4)
        tx = (centroid_2d[0] - self.camera_matrix[0, 2]) * tz / self.camera_matrix[0, 0]
        ty = (centroid_2d[1] - self.camera_matrix[1, 2]) * tz / self.camera_matrix[1, 1]
        t = np.array([[tx], [ty], [tz]], dtype=np.float64)

        return R, t

    @staticmethod
    def rotation_matrix_to_euler_yxz(R: np.ndarray) -> Tuple[float, float, float]:
        """
        Converts 3x3 rotation matrix to Euler angles (yaw, pitch, roll) in degrees
        using intrinsic Y-X-Z convention.
        Yaw: rotation around Y (+: turn right)
        Pitch: rotation around X (+: tilt down, -: tilt up)
        Roll: rotation around Z (+: tilt right ear to shoulder)
        """
        # Guard gimbal lock
        sin_pitch = -R[1, 2]
        sin_pitch = max(-1.0, min(1.0, sin_pitch))
        pitch_rad = math.asin(sin_pitch)

        cos_pitch = math.cos(pitch_rad)
        if abs(cos_pitch) > 1e-4:
            yaw_rad = math.atan2(R[0, 2], R[2, 2])
            roll_rad = math.atan2(R[1, 0], R[1, 1])
        else:
            # Gimbal lock at pitch = +- 90 deg
            yaw_rad = math.atan2(-R[2, 0], R[0, 0])
            roll_rad = 0.0

        yaw_deg = math.degrees(yaw_rad)
        pitch_deg = math.degrees(pitch_rad)
        roll_deg = math.degrees(roll_rad)

        return yaw_deg, pitch_deg, roll_deg
