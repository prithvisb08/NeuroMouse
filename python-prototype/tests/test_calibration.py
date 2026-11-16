"""
Unit Tests for Neutral Pose Calibrator.
Verifies MAD outlier rejection and baseline estimation against shared/test-vectors/calibration.json.
"""

import json
import os
import pytest
from motion.calibration import NeutralPoseCalibrator


def test_calibration_against_golden_vectors():
    path = os.path.join(
        os.path.dirname(__file__), "..", "..", "shared", "test-vectors", "calibration.json"
    )
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    samples = data["samples"]
    inliers, mean_val, std_dev = NeutralPoseCalibrator._compute_mad_inliers(samples)

    assert len(inliers) == data["inlier_count"]
    assert abs(mean_val - data["trimmed_mean"]) < 1e-6
    # Verify known outliers (25.0 and -15.0) are stripped
    for outl in data["outliers"]:
        assert outl not in inliers


def test_excessive_movement_rejection():
    calibrator = NeutralPoseCalibrator(duration_sec=2.0, min_frames=10, max_std_deg=1.8)
    calibrator.start(0.0)

    # Inject continuously dispersed samples around median (std > 1.8)
    # Samples ranging steadily from -4.0 to +4.0 degrees
    spread_samples = [-4.0, -3.5, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 3.5, 4.0, -2.5, 2.5]
    for i, yaw in enumerate(spread_samples):
        calibrator.add_sample(yaw, 0.0, 0.0, timestamp=i * 0.1)

    result = calibrator.finalize()
    assert not result.success
    assert "Excessive head movement" in (result.error_message or "")


def test_insufficient_frames_rejection():
    calibrator = NeutralPoseCalibrator(duration_sec=2.0, min_frames=45)
    calibrator.start(0.0)

    # Only add 10 frames
    for i in range(10):
        calibrator.add_sample(0.0, 0.0, 0.0, timestamp=i * 0.1)

    result = calibrator.finalize()
    assert not result.success
    assert "Insufficient frames" in (result.error_message or "")
