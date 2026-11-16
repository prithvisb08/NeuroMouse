"""
Unit Tests for 3D Craniofacial Pose Estimation.
Verifies rigid upper craniofacial anchor geometry, PnP pose recovery,
and Euler Y-X-Z intrinsic angle decomposition.
"""

import math
import numpy as np
import pytest
from vision.head_pose import (
    CraniofacialPoseEstimator,
    CANONICAL_3D_POINTS,
    UPPER_CRANIOFACIAL_INDICES,
)


def test_canonical_points_shape():
    assert CANONICAL_3D_POINTS.shape == (8, 3)
    assert len(UPPER_CRANIOFACIAL_INDICES) == 8
    # Nose tip must be origin
    np.testing.assert_allclose(CANONICAL_3D_POINTS[0], [0.0, 0.0, 0.0])


def test_euler_decomposition_pure_axes():
    # 1. Pure Yaw (Rotation around Y)
    yaw_target_deg = 15.0
    rad_y = math.radians(yaw_target_deg)
    R_yaw = np.array([
        [math.cos(rad_y), 0.0, math.sin(rad_y)],
        [0.0, 1.0, 0.0],
        [-math.sin(rad_y), 0.0, math.cos(rad_y)],
    ])
    y, p, r = CraniofacialPoseEstimator.rotation_matrix_to_euler_yxz(R_yaw)
    assert abs(y - yaw_target_deg) < 1e-4
    assert abs(p) < 1e-4
    assert abs(r) < 1e-4

    # 2. Pure Pitch (Rotation around X)
    pitch_target_deg = -10.0  # Up tilt
    rad_x = math.radians(pitch_target_deg)
    R_pitch = np.array([
        [1.0, 0.0, 0.0],
        [0.0, math.cos(rad_x), -math.sin(rad_x)],
        [0.0, math.sin(rad_x), math.cos(rad_x)],
    ])
    y, p, r = CraniofacialPoseEstimator.rotation_matrix_to_euler_yxz(R_pitch)
    assert abs(y) < 1e-4
    assert abs(p - pitch_target_deg) < 1e-4
    assert abs(r) < 1e-4

    # 3. Pure Roll (Rotation around Z)
    roll_target_deg = 8.0
    rad_z = math.radians(roll_target_deg)
    R_roll = np.array([
        [math.cos(rad_z), -math.sin(rad_z), 0.0],
        [math.sin(rad_z), math.cos(rad_z), 0.0],
        [0.0, 0.0, 1.0],
    ])
    y, p, r = CraniofacialPoseEstimator.rotation_matrix_to_euler_yxz(R_roll)
    assert abs(y) < 1e-4
    assert abs(p) < 1e-4
    assert abs(r - roll_target_deg) < 1e-4


def test_pose_estimation_projected_neutral():
    estimator = CraniofacialPoseEstimator(camera_width=640, camera_height=480)
    # Project canonical 3D model into 2D pinhole camera at Tz = 500 mm
    tz = 500.0
    pts_2d = np.zeros((8, 2), dtype=np.float64)
    for i in range(8):
        x3, y3, z3 = CANONICAL_3D_POINTS[i]
        depth = tz + z3
        u = (x3 * 640.0) / depth + 320.0
        v = (y3 * 640.0) / depth + 240.0
        pts_2d[i] = [u, v]

    yaw, pitch, roll, R, t = estimator.estimate_pose(pts_2d)
    assert abs(yaw) < 2.0
    assert abs(pitch) < 2.0
    assert abs(roll) < 2.0
