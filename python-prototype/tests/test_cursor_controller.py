"""
Tests for Cross-Platform Cursor Controller (macOS & Windows).
"""

from unittest.mock import MagicMock, patch
import sys
import pytest

from cursor.cursor_controller import (
    CursorController,
    _FallbackBackend,
    _WindowsBackend,
)


def test_cursor_controller_initialization():
    cursor = CursorController(physical_override_pause=True, override_threshold_px=40.0)
    assert cursor is not None
    assert cursor.platform_name in ("macOS", "Windows", "Fallback")


def test_cursor_controller_bounds_and_position():
    cursor = CursorController()
    w, h = cursor.get_screen_bounds()
    assert w > 0
    assert h > 0

    x, y = cursor.get_current_position()
    assert isinstance(x, (int, float))
    assert isinstance(y, (int, float))


def test_cursor_controller_move_and_override():
    cursor = CursorController(physical_override_pause=True, override_threshold_px=20.0, pause_duration_sec=2.0)
    t0 = 100.0

    # First move should succeed
    moved = cursor.move_to(500.0, 400.0, timestamp=t0)
    assert moved is True
    assert cursor._last_commanded_x == 500.0
    assert cursor._last_commanded_y == 400.0

    # Simulate user physical mouse movement by mocking get_current_position
    with patch.object(cursor, "get_current_position", return_value=(600.0, 400.0)):
        # Delta is 100px > 20px threshold
        moved = cursor.move_to(505.0, 400.0, timestamp=t0 + 0.1)
        assert moved is False
        assert cursor.is_override_paused(t0 + 0.5) is True

        # While paused, further movement should be blocked
        moved = cursor.move_to(510.0, 400.0, timestamp=t0 + 0.5)
        assert moved is False

        # After pause duration expires, should be unpaused
        assert cursor.is_override_paused(t0 + 2.5) is False


def test_cursor_controller_drag_state():
    cursor = CursorController()
    cursor.start_drag(100.0, 200.0)
    assert cursor.is_dragging is True

    cursor.end_drag(100.0, 200.0)
    assert cursor.is_dragging is False


def test_cursor_fallback_backend():
    backend = _FallbackBackend()
    assert backend.get_screen_bounds() == (1920.0, 1080.0)
    assert backend.get_current_position() == (960.0, 540.0)

    backend.move_to(300.0, 400.0)
    assert backend.get_current_position() == (300.0, 400.0)

    backend.click(False, 300.0, 400.0)
    backend.scroll(5)
    backend.play_click_sound()


def test_windows_backend_mock():
    # Test Windows backend logic with mocked ctypes.windll
    mock_user32 = MagicMock()
    mock_shcore = MagicMock()
    mock_user32.GetSystemMetrics.side_effect = lambda idx: 2560 if idx == 0 else 1440
    mock_user32.GetCursorPos.return_value = 1

    mock_ctypes = MagicMock()
    mock_ctypes.windll.user32 = mock_user32
    mock_ctypes.windll.shcore = mock_shcore
    mock_ctypes.c_long = int

    with patch.dict("sys.modules", {"ctypes": mock_ctypes}):
        with patch("sys.platform", "win32"):
            # Instantiate with mocked platform
            with patch("cursor.cursor_controller._WindowsBackend.get_screen_bounds", return_value=(2560.0, 1440.0)):
                with patch("cursor.cursor_controller._WindowsBackend.get_current_position", return_value=(500.0, 300.0)):
                    controller = CursorController()
                    assert controller.platform_name == "Windows"
                    bounds = controller.get_screen_bounds()
                    assert bounds == (2560.0, 1440.0)
                    pos = controller.get_current_position()
                    assert pos == (500.0, 300.0)
