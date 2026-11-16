"""
Camera Package for HeadMotion Mouse.
Provides camera device management and frame processing.
"""

from .camera_manager import CameraManager
from .frame_processor import FrameProcessor

__all__ = [
    "CameraManager",
    "FrameProcessor",
]
