"""
Gestures Package for HeadMotion Mouse.
Provides dwell clicking, intentional blink recognition, and nod detection.
"""

from .dwell_click import DwellClickDetector, DwellState
from .blink_detector import BlinkDetector
from .nod_detector import NodDetector
from .gesture_manager import GestureManager

__all__ = [
    "DwellClickDetector",
    "DwellState",
    "BlinkDetector",
    "NodDetector",
    "GestureManager",
]
