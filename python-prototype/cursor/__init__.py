"""
Cursor and Scroll Control Package for HeadMotion Mouse.
Provides direct Quartz/CoreGraphics mouse positioning, clicks, and scrolling.
"""

from .cursor_controller import CursorController
from .scroll_controller import ScrollController

__all__ = [
    "CursorController",
    "ScrollController",
]
