import Foundation
import CoreGraphics

public final class CursorController: @unchecked Sendable {
    public var physicalOverridePause: Bool
    public var overrideThresholdPx: Double
    public var pauseDurationSec: Double
    public private(set) var isDragging: Bool = false

    private var lastCommandedPos: CGPoint?
    private var overridePausedUntil: Double = 0.0

    public init(
        physicalOverridePause: Bool = true,
        overrideThresholdPx: Double = 40.0,
        pauseDurationSec: Double = 3.0
    ) {
        self.physicalOverridePause = physicalOverridePause
        self.overrideThresholdPx = overrideThresholdPx
        self.pauseDurationSec = pauseDurationSec
    }

    public func getCurrentPosition() -> CGPoint {
        if let event = CGEvent(source: nil) {
            return event.location
        }
        return .zero
    }

    public func isOverridePaused(now: Double) -> Bool {
        if physicalOverridePause && (now < overridePausedUntil) {
            return true
        }
        if overridePausedUntil > 0 {
            // Pause window has expired: clear and re-sync cursor position
            overridePausedUntil = 0
            lastCommandedPos = getCurrentPosition()
        }
        return false
    }

    @discardableResult
    public func moveTo(_ targetPos: CGPoint, timestamp: Double) -> Bool {
        let now = timestamp

        if isOverridePaused(now: now) {
            return false
        }

        // Compare observed cursor position with last commanded position
        if physicalOverridePause, let lastPos = lastCommandedPos {
            let actual = getCurrentPosition()
            let delta = hypot(actual.x - lastPos.x, actual.y - lastPos.y)
            if delta > overrideThresholdPx {
                // Physical trackpad/mouse moved by user!
                overridePausedUntil = now + pauseDurationSec
                lastCommandedPos = actual
                return false
            }
        }

        let mouseType: CGEventType = isDragging ? .leftMouseDragged : .mouseMoved
        if let event = CGEvent(
            mouseEventSource: nil,
            mouseType: mouseType,
            mouseCursorPosition: targetPos,
            mouseButton: .left
        ) {
            event.post(tap: .cghidEventTap)
        }

        lastCommandedPos = targetPos
        return true
    }

    public func startDrag(at position: CGPoint? = nil) {
        let pos = position ?? getCurrentPosition()
        if let downEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left) {
            downEvent.post(tap: .cghidEventTap)
        }
        isDragging = true
        lastCommandedPos = pos
    }

    public func endDrag(at position: CGPoint? = nil) {
        let pos = position ?? getCurrentPosition()
        if let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left) {
            upEvent.post(tap: .cghidEventTap)
        }
        isDragging = false
        lastCommandedPos = pos
    }

    public func click(isRightClick: Bool = false, at position: CGPoint? = nil) {
        let pos = position ?? getCurrentPosition()

        let downType: CGEventType = isRightClick ? .rightMouseDown : .leftMouseDown
        let upType: CGEventType = isRightClick ? .rightMouseUp : .leftMouseUp
        let btn: CGMouseButton = isRightClick ? .right : .left

        if let downEvent = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: pos, mouseButton: btn) {
            downEvent.post(tap: .cghidEventTap)
        }

        usleep(10000) // 10ms hold

        if let upEvent = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: pos, mouseButton: btn) {
            upEvent.post(tap: .cghidEventTap)
        }

        lastCommandedPos = pos
    }

    public func scroll(dy: Int32) {
        if let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: dy,
            wheel2: 0,
            wheel3: 0
        ) {
            event.post(tap: .cghidEventTap)
        }
    }
}
