"""
Motion Processing Package for HeadMotion Mouse.
Provides dead-zone filtering, Casiez One Euro filtering, calibration, and movement mapping.
"""

from .dead_zone import apply_dead_zone
from .one_euro_filter import OneEuroFilter
from .calibration import NeutralPoseCalibrator, CalibrationResult
from .movement_mapper import MovementMapper, MappingMode

__all__ = [
    "apply_dead_zone",
    "OneEuroFilter",
    "NeutralPoseCalibrator",
    "CalibrationResult",
    "MovementMapper",
    "MappingMode",
]
