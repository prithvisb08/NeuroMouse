"""
Unit Tests for Casiez One Euro (1€) Filter.
Verifies mathematical parity against shared/test-vectors/one_euro.json.
"""

import json
import os
import pytest
from motion.one_euro_filter import OneEuroFilter


def test_one_euro_filter_against_golden_vectors():
    test_vector_path = os.path.join(
        os.path.dirname(__file__), "..", "..", "shared", "test-vectors", "one_euro.json"
    )
    assert os.path.exists(test_vector_path), f"Missing golden test vector at {test_vector_path}"

    with open(test_vector_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    filter_instance = OneEuroFilter(
        min_cutoff=data["min_cutoff"],
        beta=data["beta"],
        d_cutoff=data["d_cutoff"],
    )

    for case in data["cases"]:
        t = case["t"]
        x_in = case["input"]
        expected = case["expected"]
        result = filter_instance.filter(x_in, t)
        assert abs(result - expected) < 1e-5, f"Mismatch at t={t}: expected {expected}, got {result}"


def test_one_euro_filter_reset():
    f = OneEuroFilter()
    assert f.filter(10.0, 0.0) == 10.0
    assert f.filter(20.0, 0.033) < 20.0
    f.reset()
    # After reset, the first sample must return the raw value without lag
    assert f.filter(50.0, 1.0) == 50.0
