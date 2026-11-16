"""
Unit & Regression Tests for Parallax Compensation & Translation Invariance.
Validates that leaning the body (lateral head translation) without rotating
produces ~0 angular cursor drift, as enforced by test_parallax.py and ParallaxTests.swift.
"""

import json
import math
import os
import pytest
from motion.movement_mapper import MovementMapper, MappingMode


def test_parallax_compensation_against_golden_vectors():
    path = os.path.join(
        os.path.dirname(__file__), "..", "..", "shared", "test-vectors", "parallax.json"
    )
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    mapper = MovementMapper(k_parallax=data["k_parallax"])

    for case in data["cases"]:
        psi = case["psi"]
        theta = case["theta"]
        tx = case["Tx"]
        ty = case["Ty"]
        tz = case["Tz"]

        exp_psi = case["expected_psi_corr"]
        exp_theta = case["expected_theta_corr"]

        res_psi, res_theta = mapper.apply_parallax_compensation(psi, theta, tx, ty, tz)
        assert abs(res_psi - exp_psi) < 1e-6, f"Parallax yaw mismatch: expected {exp_psi}, got {res_psi}"
        assert abs(res_theta - exp_theta) < 1e-6, f"Parallax pitch mismatch: expected {exp_theta}, got {res_theta}"


def test_lean_only_translation_invariance_regression():
    """
    Lean-Only Regression:
    Simulates a user leaning sideways in a chair:
    Physical head rotation is held strictly constant at neutral (0.0 deg),
    while translation shifts laterally from Tx = 0 mm to Tx = 120 mm.
    In pure rotation mode, cursor delta must remain exactly 0.0.
    """
    mapper = MovementMapper(
        screen_width=1920.0,
        screen_height=1080.0,
        mapping_mode=MappingMode.DIRECT_ABSOLUTE,
    )
    mapper.set_baseline(0.0, 0.0, 0.0)

    # Initial center cursor position
    x0, y0 = mapper.process(
        raw_yaw=0.0,
        raw_pitch=0.0,
        raw_roll=0.0,
        timestamp=0.0,
        tx_mm=0.0,
        ty_mm=0.0,
        tz_mm=500.0,
        is_hybrid_pose=False,
    )

    # Simulate lateral body lean trajectory over 10 frames
    for step in range(1, 11):
        tx_lean = step * 12.0  # 12mm to 120mm sideways lean
        t_now = step * 0.0333

        x_curr, y_curr = mapper.process(
            raw_yaw=0.0,
            raw_pitch=0.0,
            raw_roll=0.0,
            timestamp=t_now,
            tx_mm=tx_lean,
            ty_mm=0.0,
            tz_mm=500.0,
            is_hybrid_pose=False,
        )

        cursor_delta = math.hypot(x_curr - x0, y_curr - y0)
        assert cursor_delta < 1e-4, f"False cursor drift during pure body lean: delta={cursor_delta} px"
