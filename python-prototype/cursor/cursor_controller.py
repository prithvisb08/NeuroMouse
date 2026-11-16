"""
Cross-Platform Native Cursor Controller (macOS & Windows).
Injects mouse movements, clicks, and scrolls with ultra-low latency:
- On macOS: CoreGraphics C APIs (ctypes / Quartz) with Retina scaling awareness
- On Windows: Win32 User32 APIs (ctypes / user32.dll) with Per-Monitor DPI awareness
- On other/CI environments: In-memory fallback backend
Includes physical input override detection and audio feedback.
"""

import ctypes
from ctypes import c_double, Structure, c_void_p, c_uint32, c_int32
import os
import subprocess
import sys
import time
from typing import Optional, Tuple


class CGPoint(Structure):
    _fields_ = [("x", c_double), ("y", c_double)]


class CGRect(Structure):
    _fields_ = [("origin", CGPoint), ("size", CGPoint)]


class _MacOSBackend:
    """macOS CoreGraphics low-latency mouse driver."""

    kCGEventNull = 0
    kCGEventLeftMouseDown = 1
    kCGEventLeftMouseUp = 2
    kCGEventRightMouseDown = 3
    kCGEventRightMouseUp = 4
    kCGEventMouseMoved = 5
    kCGEventLeftMouseDragged = 6
    kCGEventRightMouseDragged = 7
    kCGEventScrollWheel = 22

    kCGMouseButtonLeft = 0
    kCGMouseButtonRight = 1
    kCGHIDEventTap = 0

    def __init__(self) -> None:
        self._cg = ctypes.cdll.LoadLibrary(
            "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
        )
        self._cf = ctypes.cdll.LoadLibrary(
            "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
        )

        self._cf.CFRelease.argtypes = [c_void_p]

        self._cg.CGEventCreate.restype = c_void_p
        self._cg.CGEventCreate.argtypes = [c_void_p]

        self._cg.CGEventGetLocation.restype = CGPoint
        self._cg.CGEventGetLocation.argtypes = [c_void_p]

        self._cg.CGEventCreateMouseEvent.restype = c_void_p
        self._cg.CGEventCreateMouseEvent.argtypes = [
            c_void_p,
            c_uint32,
            CGPoint,
            c_uint32,
        ]

        self._cg.CGEventCreateScrollWheelEvent.restype = c_void_p
        self._cg.CGEventCreateScrollWheelEvent.argtypes = [
            c_void_p,
            c_uint32,
            c_uint32,
            c_int32,
        ]

        self._cg.CGEventPost.argtypes = [c_uint32, c_void_p]
        self._cg.CGWarpMouseCursorPosition.argtypes = [CGPoint]

        self._cg.CGMainDisplayID.restype = c_uint32
        self._cg.CGMainDisplayID.argtypes = []

        self._cg.CGDisplayBounds.restype = CGRect
        self._cg.CGDisplayBounds.argtypes = [c_uint32]

    def get_screen_bounds(self) -> Tuple[float, float]:
        try:
            main_id = self._cg.CGMainDisplayID()
            rect = self._cg.CGDisplayBounds(main_id)
            return rect.size.x, rect.size.y
        except Exception:
            return 1920.0, 1080.0

    def get_current_position(self) -> Tuple[float, float]:
        event = self._cg.CGEventCreate(None)
        if not event:
            return 0.0, 0.0
        try:
            loc = self._cg.CGEventGetLocation(event)
            return loc.x, loc.y
        finally:
            self._cf.CFRelease(event)

    def move_to(self, target_x: float, target_y: float, is_dragging: bool = False) -> None:
        pt = CGPoint(x=c_double(target_x), y=c_double(target_y))
        mouse_type = self.kCGEventLeftMouseDragged if is_dragging else self.kCGEventMouseMoved
        event = self._cg.CGEventCreateMouseEvent(
            None,
            mouse_type,
            pt,
            self.kCGMouseButtonLeft,
        )
        if event:
            self._cg.CGEventPost(self.kCGHIDEventTap, event)
            self._cf.CFRelease(event)

    def start_drag(self, cx: float, cy: float) -> None:
        pt = CGPoint(x=c_double(cx), y=c_double(cy))
        event = self._cg.CGEventCreateMouseEvent(None, self.kCGEventLeftMouseDown, pt, self.kCGMouseButtonLeft)
        if event:
            self._cg.CGEventPost(self.kCGHIDEventTap, event)
            self._cf.CFRelease(event)

    def end_drag(self, cx: float, cy: float) -> None:
        pt = CGPoint(x=c_double(cx), y=c_double(cy))
        event = self._cg.CGEventCreateMouseEvent(None, self.kCGEventLeftMouseUp, pt, self.kCGMouseButtonLeft)
        if event:
            self._cg.CGEventPost(self.kCGHIDEventTap, event)
            self._cf.CFRelease(event)

    def click(self, is_right_click: bool, cx: float, cy: float) -> None:
        pt = CGPoint(x=c_double(cx), y=c_double(cy))
        if is_right_click:
            down_type = self.kCGEventRightMouseDown
            up_type = self.kCGEventRightMouseUp
            btn = self.kCGMouseButtonRight
        else:
            down_type = self.kCGEventLeftMouseDown
            up_type = self.kCGEventLeftMouseUp
            btn = self.kCGMouseButtonLeft

        down_evt = self._cg.CGEventCreateMouseEvent(None, down_type, pt, btn)
        if down_evt:
            self._cg.CGEventPost(self.kCGHIDEventTap, down_evt)
            self._cf.CFRelease(down_evt)

        time.sleep(0.01)

        up_evt = self._cg.CGEventCreateMouseEvent(None, up_type, pt, btn)
        if up_evt:
            self._cg.CGEventPost(self.kCGHIDEventTap, up_evt)
            self._cf.CFRelease(up_evt)

    def scroll(self, scroll_dy: int) -> None:
        event = self._cg.CGEventCreateScrollWheelEvent(
            None,
            0,
            1,
            c_int32(scroll_dy),
        )
        if event:
            self._cg.CGEventPost(self.kCGHIDEventTap, event)
            self._cf.CFRelease(event)

    def play_click_sound(self) -> None:
        try:
            subprocess.Popen(
                ["afplay", "/System/Library/Sounds/Tink.aiff"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass


class _WindowsBackend:
    """Windows Win32 User32 low-latency mouse driver with DPI awareness."""

    MOUSEEVENTF_MOVE = 0x0001
    MOUSEEVENTF_LEFTDOWN = 0x0002
    MOUSEEVENTF_LEFTUP = 0x0004
    MOUSEEVENTF_RIGHTDOWN = 0x0008
    MOUSEEVENTF_RIGHTUP = 0x0010
    MOUSEEVENTF_WHEEL = 0x0800
    WHEEL_DELTA = 120

    def __init__(self) -> None:
        import ctypes
        self._ctypes = ctypes
        self._user32 = ctypes.windll.user32

        # Set Per-Monitor DPI Awareness so screen bounds and coordinates match physical pixels
        try:
            # PROCESS_PER_MONITOR_DPI_AWARE = 2
            ctypes.windll.shcore.SetProcessDpiAwareness(2)
        except Exception:
            try:
                self._user32.SetProcessDPIAware()
            except Exception:
                pass

        class POINT(ctypes.Structure):
            _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]

        self._POINT = POINT

    def get_screen_bounds(self) -> Tuple[float, float]:
        try:
            w = float(self._user32.GetSystemMetrics(0))  # SM_CXSCREEN
            h = float(self._user32.GetSystemMetrics(1))  # SM_CYSCREEN
            if w > 0 and h > 0:
                return w, h
        except Exception:
            pass
        return 1920.0, 1080.0

    def get_current_position(self) -> Tuple[float, float]:
        pt = self._POINT()
        if self._user32.GetCursorPos(self._ctypes.byref(pt)):
            return float(pt.x), float(pt.y)
        return 0.0, 0.0

    def move_to(self, target_x: float, target_y: float, is_dragging: bool = False) -> None:
        self._user32.SetCursorPos(int(round(target_x)), int(round(target_y)))

    def start_drag(self, cx: float, cy: float) -> None:
        self._user32.SetCursorPos(int(round(cx)), int(round(cy)))
        self._user32.mouse_event(self.MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)

    def end_drag(self, cx: float, cy: float) -> None:
        self._user32.SetCursorPos(int(round(cx)), int(round(cy)))
        self._user32.mouse_event(self.MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)

    def click(self, is_right_click: bool, cx: float, cy: float) -> None:
        self._user32.SetCursorPos(int(round(cx)), int(round(cy)))
        if is_right_click:
            down = self.MOUSEEVENTF_RIGHTDOWN
            up = self.MOUSEEVENTF_RIGHTUP
        else:
            down = self.MOUSEEVENTF_LEFTDOWN
            up = self.MOUSEEVENTF_LEFTUP

        self._user32.mouse_event(down, 0, 0, 0, 0)
        time.sleep(0.01)
        self._user32.mouse_event(up, 0, 0, 0, 0)

    def scroll(self, scroll_dy: int) -> None:
        # Standard Windows wheel delta is 120 per click
        delta = int(scroll_dy * (self.WHEEL_DELTA / 2))
        self._user32.mouse_event(self.MOUSEEVENTF_WHEEL, 0, 0, delta, 0)

    def play_click_sound(self) -> None:
        try:
            import winsound
            winsound.MessageBeep(winsound.MB_OK)
        except Exception:
            pass


class _FallbackBackend:
    """In-memory fallback backend for testing, CI, or unsupported environments."""

    def __init__(self) -> None:
        self._x = 960.0
        self._y = 540.0

    def get_screen_bounds(self) -> Tuple[float, float]:
        return 1920.0, 1080.0

    def get_current_position(self) -> Tuple[float, float]:
        return self._x, self._y

    def move_to(self, target_x: float, target_y: float, is_dragging: bool = False) -> None:
        self._x = target_x
        self._y = target_y

    def start_drag(self, cx: float, cy: float) -> None:
        self._x = cx
        self._y = cy

    def end_drag(self, cx: float, cy: float) -> None:
        self._x = cx
        self._y = cy

    def click(self, is_right_click: bool, cx: float, cy: float) -> None:
        self._x = cx
        self._y = cy

    def scroll(self, scroll_dy: int) -> None:
        pass

    def play_click_sound(self) -> None:
        pass


class CursorController:
    """
    Cross-Platform Low-Latency Mouse Driver.
    Automatically binds to macOS CoreGraphics or Windows Win32 User32.
    """

    # CGEventType constants for backwards compatibility
    kCGEventNull = 0
    kCGEventLeftMouseDown = 1
    kCGEventLeftMouseUp = 2
    kCGEventRightMouseDown = 3
    kCGEventRightMouseUp = 4
    kCGEventMouseMoved = 5
    kCGEventLeftMouseDragged = 6
    kCGEventRightMouseDragged = 7
    kCGEventScrollWheel = 22

    # CGMouseButton constants
    kCGMouseButtonLeft = 0
    kCGMouseButtonRight = 1

    # CGEventTapLocation
    kCGHIDEventTap = 0

    def __init__(
        self,
        physical_override_pause: bool = True,
        override_threshold_px: float = 40.0,
        pause_duration_sec: float = 3.0,
    ) -> None:
        self.override_enabled = physical_override_pause
        self.override_threshold = override_threshold_px
        self.pause_duration = pause_duration_sec

        # Tracking state
        self._last_commanded_x: Optional[float] = None
        self._last_commanded_y: Optional[float] = None
        self._override_paused_until: float = 0.0
        self.is_dragging: bool = False
        self.audio_feedback: bool = True

        # Platform backend selection
        if sys.platform == "darwin":
            try:
                self._backend = _MacOSBackend()
                self.platform_name = "macOS"
            except Exception as e:
                print(f"[WARN] Failed to initialize macOS CoreGraphics backend: {e}. Using fallback.")
                self._backend = _FallbackBackend()
                self.platform_name = "Fallback"
        elif sys.platform == "win32":
            try:
                self._backend = _WindowsBackend()
                self.platform_name = "Windows"
            except Exception as e:
                print(f"[WARN] Failed to initialize Windows user32 backend: {e}. Using fallback.")
                self._backend = _FallbackBackend()
                self.platform_name = "Fallback"
        else:
            self._backend = _FallbackBackend()
            self.platform_name = "Fallback"

    def get_screen_bounds(self) -> Tuple[float, float]:
        """Returns the active display (width, height) in points/pixels."""
        return self._backend.get_screen_bounds()

    def get_current_position(self) -> Tuple[float, float]:
        """Queries the current system cursor position."""
        return self._backend.get_current_position()

    def is_override_paused(self, now: float) -> bool:
        """Returns True if tracking is temporarily paused due to physical mouse movement."""
        return self.override_enabled and (now < self._override_paused_until)

    def move_to(self, target_x: float, target_y: float, timestamp: float) -> bool:
        """
        Moves the system cursor to (target_x, target_y), checking for physical user override.

        Returns:
            True if cursor was moved, False if paused due to physical input override.
        """
        now = timestamp

        # Check if already in override pause
        if self.is_override_paused(now):
            return False

        # Physical Input Override Check:
        # Compare actual cursor location with our last commanded location
        if self.override_enabled and self._last_commanded_x is not None:
            actual_x, actual_y = self.get_current_position()
            unexplained_delta = ((actual_x - self._last_commanded_x) ** 2 +
                                 (actual_y - self._last_commanded_y) ** 2) ** 0.5
            if unexplained_delta > self.override_threshold:
                # User physically moved trackpad or mouse!
                self._override_paused_until = now + self.pause_duration
                self._last_commanded_x = actual_x
                self._last_commanded_y = actual_y
                return False

        self._backend.move_to(target_x, target_y, is_dragging=self.is_dragging)
        self._last_commanded_x = target_x
        self._last_commanded_y = target_y
        return True

    def start_drag(self, x: Optional[float] = None, y: Optional[float] = None) -> None:
        """Begins left mouse drag operation."""
        if x is None or y is None:
            cx, cy = self.get_current_position()
        else:
            cx, cy = x, y
        self._backend.start_drag(cx, cy)
        self.is_dragging = True
        self._last_commanded_x = cx
        self._last_commanded_y = cy

    def end_drag(self, x: Optional[float] = None, y: Optional[float] = None) -> None:
        """Ends left mouse drag operation."""
        if x is None or y is None:
            cx, cy = self.get_current_position()
        else:
            cx, cy = x, y
        self._backend.end_drag(cx, cy)
        self.is_dragging = False
        self._last_commanded_x = cx
        self._last_commanded_y = cy

    def click(self, is_right_click: bool = False, x: Optional[float] = None, y: Optional[float] = None) -> None:
        """Emits a mouse click at current or designated position."""
        if x is None or y is None:
            cx, cy = self.get_current_position()
        else:
            cx, cy = x, y

        self._backend.click(is_right_click, cx, cy)

        if self.audio_feedback:
            self._backend.play_click_sound()

        self._last_commanded_x = cx
        self._last_commanded_y = cy

    def scroll(self, scroll_dy: int) -> None:
        """Emits a vertical mouse scroll event."""
        self._backend.scroll(scroll_dy)
