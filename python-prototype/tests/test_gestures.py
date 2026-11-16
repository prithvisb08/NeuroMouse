"""
Unit Tests for Gesture Recognition Subsystem.
Verifies Dwell Click state machine, Eye Aspect Ratio (EAR) temporal classification,
and Nod detection impulses.
"""

import pytest
from gestures.dwell_click import DwellClickDetector, DwellState
from gestures.blink_detector import BlinkDetector
from gestures.nod_detector import NodDetector


def test_dwell_click_lifecycle():
    clicked = []
    detector = DwellClickDetector(
        dwell_radius_px=18.0,
        dwell_duration_ms=800.0,
        dwell_cooldown_ms=1000.0,
        rearm_distance_px=25.0,
        on_click=lambda pos, is_right: clicked.append((pos, is_right)),
    )

    # 1. Start at (100, 100)
    state, prog = detector.update(100.0, 100.0, timestamp=0.0)
    assert state == DwellState.DWELLING
    assert prog == 0.0

    # 2. Hold within radius for 400ms (halfway)
    state, prog = detector.update(105.0, 103.0, timestamp=0.4)
    assert state == DwellState.DWELLING
    assert 0.45 <= prog <= 0.55

    # 3. Reach 800ms -> Trigger click!
    state, prog = detector.update(106.0, 102.0, timestamp=0.81)
    assert state == DwellState.TRIGGERED
    assert len(clicked) == 1
    assert clicked[0][1] is False  # Left click

    # 4. Immediate subsequent frame -> Cooldown
    state, prog = detector.update(106.0, 102.0, timestamp=0.85)
    assert state == DwellState.COOLDOWN

    # 5. After cooldown (1.9s total) but within 25px re-arm boundary -> no new dwell
    state, prog = detector.update(105.0, 102.0, timestamp=1.9)
    assert state == DwellState.IDLE
    assert len(clicked) == 1

    # 6. Move past 25px re-arm distance -> New dwell begins!
    state, prog = detector.update(140.0, 100.0, timestamp=2.0)
    assert state == DwellState.DWELLING


def test_dwell_face_loss_cancellation():
    detector = DwellClickDetector(dwell_duration_ms=800.0)
    detector.update(100.0, 100.0, timestamp=0.0, is_face_locked=True)
    assert detector.state == DwellState.DWELLING

    # Face lost!
    state, prog = detector.update(100.0, 100.0, timestamp=0.5, is_face_locked=False)
    assert state == DwellState.IDLE
    assert prog == 0.0


def test_blink_detector_temporal_classification():
    blinks = []
    detector = BlinkDetector(
        ear_threshold=0.20,
        min_duration_ms=280.0,
        max_duration_ms=650.0,
        on_blink_click=lambda is_right: blinks.append(is_right),
    )

    # 6 points for open eye (EAR > 0.20)
    open_eye = [(0.0, 0.0), (1.0, 1.0), (2.0, 1.0), (3.0, 0.0), (2.0, -1.0), (1.0, -1.0)]
    # 6 points for closed eye (EAR < 0.20)
    closed_eye = [(0.0, 0.0), (1.0, 0.1), (2.0, 0.1), (3.0, 0.0), (2.0, -0.1), (1.0, -0.1)]

    # 1. Natural Involuntary Blink (150ms duration) -> Ignored
    detector.update(open_eye, open_eye, timestamp=0.0)
    detector.update(closed_eye, closed_eye, timestamp=0.1)
    detector.update(open_eye, open_eye, timestamp=0.25)  # closed for 150ms
    assert len(blinks) == 0

    # 2. Deliberate Intentional Blink (400ms duration) -> Registered
    detector.update(open_eye, open_eye, timestamp=1.0)
    detector.update(closed_eye, closed_eye, timestamp=1.1)
    detector.update(open_eye, open_eye, timestamp=1.5)  # closed for 400ms
    # After double blink window expires (400ms)
    detector.update(open_eye, open_eye, timestamp=2.0)
    assert len(blinks) == 1
    assert blinks[0] is False  # Left click


def test_nod_detector():
    nods = []
    detector = NodDetector(
        pitch_threshold_deg=4.5,
        max_duration_sec=0.45,
        on_nod=lambda: nods.append(True),
    )

    # Neutral
    detector.update(delta_yaw_deg=0.0, delta_pitch_deg=0.0, timestamp=0.0)
    # Pitch down
    detector.update(delta_yaw_deg=0.5, delta_pitch_deg=5.0, timestamp=0.15)
    # Rebound back to neutral
    detector.update(delta_yaw_deg=0.2, delta_pitch_deg=1.0, timestamp=0.30)

    assert len(nods) == 1


def test_drag_and_drop_controller():
    from cursor.cursor_controller import CursorController
    controller = CursorController(physical_override_pause=False)
    assert not controller.is_dragging
    controller.start_drag(x=100.0, y=100.0)
    assert controller.is_dragging
    moved = controller.move_to(150.0, 150.0, timestamp=1.0)
    assert moved and controller.is_dragging
    controller.end_drag(x=150.0, y=150.0)
    assert not controller.is_dragging
