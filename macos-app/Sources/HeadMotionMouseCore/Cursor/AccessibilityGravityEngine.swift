import Foundation
import CoreGraphics
import ApplicationServices

public final class AccessibilityGravityEngine: @unchecked Sendable {
    public var isEnabled: Bool
    public var dampingFactor: Double
    private var lastQueryTime: Double = 0.0
    private let queryInterval: Double = 0.066 // ~15 Hz
    private let systemWideElement: AXUIElement

    public init(isEnabled: Bool = true, dampingFactor: Double = 0.45) {
        self.isEnabled = isEnabled
        self.dampingFactor = dampingFactor
        self.systemWideElement = AXUIElementCreateSystemWide()
    }

    /// Evaluates element under cursor position and returns appropriate sensitivity multiplier.
    public func evaluateDamping(at position: CGPoint, velocity: Double, timestamp: Double) -> Double {
        guard isEnabled else { return 1.0 }

        // Only query when moving slowly (velocity < 150 px/s) to conserve CPU
        guard velocity < 150.0 else { return 1.0 }

        // Throttle AX queries to ~15 Hz
        guard (timestamp - lastQueryTime) >= queryInterval else {
            return 1.0
        }
        lastQueryTime = timestamp

        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(position.x),
            Float(position.y),
            &element
        )

        guard result == .success, let axElement = element else {
            return 1.0
        }

        var roleValue: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(
            axElement,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        guard roleResult == .success, let role = roleValue as? String else {
            return 1.0
        }

        // Clickable interactive roles that benefit from target magnetism
        let clickableRoles: Set<String> = [
            kAXButtonRole as String,
            kAXRadioButtonRole as String,
            kAXCheckBoxRole as String,
            kAXPopUpButtonRole as String,
            kAXMenuButtonRole as String,
            kAXMenuItemRole as String,
            "AXLink",
            "AXTabButton"
        ]

        if clickableRoles.contains(role) {
            return dampingFactor
        }

        return 1.0
    }
}
