"""
Smooth Dead-Zone Transfer Function.
Implements C0 and C1 continuous dead-band filtering to eliminate resting tremor
without abrupt motion step-discontinuities.
"""

from typing import Union


def apply_dead_zone(val: float, threshold: float = 1.2, epsilon: float = 1e-6) -> float:
    """
    Applies a quadratic asymptotic dead-zone function to the input angle delta.

    Args:
        val: Raw angular displacement in degrees.
        threshold: Dead-zone boundary threshold 'd' in degrees.
        epsilon: Small smoothing constant to ensure numerical stability.

    Returns:
        Filtered angular displacement. Exactly 0 if |val| <= threshold,
        smoothly emerging with zero initial derivative above threshold.
    """
    abs_val = abs(val)
    if abs_val <= threshold:
        return 0.0

    diff = abs_val - threshold
    sign = 1.0 if val > 0 else -1.0
    return sign * (diff * diff) / (diff + epsilon)
