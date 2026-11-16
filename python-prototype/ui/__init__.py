"""
UI Package for HeadMotion Mouse Python Prototype.
Provides debug window and spatial cursor HUD overlay.
"""

from .debug_window import DebugWindow
from .overlay import SpatialCursorOverlay

__all__ = [
    "DebugWindow",
    "SpatialCursorOverlay",
]
