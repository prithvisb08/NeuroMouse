"""
Unit Tests for Movement Mapper & Dead Zone.
Verifies mathematical parity against shared/test-vectors/dead_zone.json and movement_mapper.json.
"""

import json
import math
import os
import pytest
from motion.dead_zone import apply_dead_zone
from motion.movement_mapper import MovementMapper, MappingMode


def test_dead_zone_against_golden_vectors():
    path = os.path.join(
        os.path.dirname(__file__), "..", "..", "shared", "test-vectors", "dead_zone.json"
    )
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    threshold = data["threshold"]
    epsilon = data["epsilon"]

    for case in data["cases"]:
        val = case["input"]
        expected = case["expected"]
        result = apply_dead_zone(val, threshold=threshold, epsilon=epsilon)
        assert abs(result - expected) < 1e-6, f"Dead zone mismatch for {val}: expected {expected}, got {result}"


def test_movement_mapper_roll_projection():
    path = os.path.join(
        os.path.dirname(__file__), "..", "..", "shared", "test-vectors", "movement_mapper.json"
    )
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    mapper = MovementMapper(
        screen_width=data["screen_width"],
        screen_height=data["screen_height"],
        yaw_range_deg=data["yaw_range_deg"],
        pitch_range_deg=data["pitch_range_deg"],
    )

    phi0 = data["calibrated_roll_deg"]
    for case in data["cases"]:
        d_psi = case["delta_psi"]
        d_theta = case["delta_theta"]
        exp_psi = case["expected_psi_proj"]
        exp_theta = case["expected_theta_proj"]

        res_psi, res_theta = mapper.project_roll_horizon(d_psi, d_theta, phi0)
        assert abs(res_psi - exp_psi) < 1e-6, f"Roll projected yaw mismatch: expected {exp_psi}, got {res_psi}"
        assert abs(res_theta - exp_theta) < 1e-6, f"Roll projected pitch mismatch: expected {exp_theta}, got {res_theta}"


def test_screen_clamping():
    mapper = MovementMapper(
        screen_width=1920.0,
        screen_height=1080.0,
        mapping_mode=MappingMode.DIRECT_ABSOLUTE,
    )
    mapper.set_baseline(0.0, 0.0, 0.0)

    # Extreme yaw/pitch beyond range
    x, y = mapper.process(100.0, 100.0, 0.0, timestamp=1.0)
    assert 0.0 <= x <= 1920.0
    assert 0.0 <= y <= 1080.0

    x_neg, y_neg = mapper.process(-100.0, -100.0, 0.0, timestamp=2.0)
    assert 0.0 <= x_neg <= 1920.0
    assert 0.0 <= y_neg <= 1080.0
