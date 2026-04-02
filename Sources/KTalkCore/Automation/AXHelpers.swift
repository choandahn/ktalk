import AppKit
import ApplicationServices

/// macOS Accessibility API 저수준 헬퍼
public enum AXHelpers {

    // MARK: - App Element

    public static func appElement(bundleId: String) throws -> AXUIElement {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
            throw KTalkError.appNotInstalled
        }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    public static func activateApp(bundleId: String) throws {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
            throw KTalkError.appNotInstalled
        }
        app.activate()
        Thread.sleep(forTimeInterval: 0.3)
    }

    // MARK: - Attribute Access

    public static func attribute(_ element: AXUIElement, _ attr: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    public static func intAttribute(_ element: AXUIElement, _ attr: String) -> Int? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard result == .success else { return nil }
        return value as? Int
    }

    public static func boolAttribute(_ element: AXUIElement, _ attr: String) -> Bool? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard result == .success else { return nil }
        if let num = value as? NSNumber { return num.boolValue }
        return nil
    }

    public static func children(_ element: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard result == .success, let children = value as? [AXUIElement] else { return [] }
        return children
    }

    public static func windows(_ appElement: AXUIElement) -> [AXUIElement] {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else { return [] }
        return windows
    }

    public static func role(_ element: AXUIElement) -> String? {
        attribute(element, kAXRoleAttribute as String)
    }

    public static func title(_ element: AXUIElement) -> String? {
        attribute(element, kAXTitleAttribute as String)
    }

    public static func value(_ element: AXUIElement) -> String? {
        attribute(element, kAXValueAttribute as String)
    }

    public static func description(_ element: AXUIElement) -> String? {
        attribute(element, kAXDescriptionAttribute as String)
    }

    public static func roleDescription(_ element: AXUIElement) -> String? {
        attribute(element, kAXRoleDescriptionAttribute as String)
    }

    public static func identifier(_ element: AXUIElement) -> String? {
        attribute(element, kAXIdentifierAttribute as String)
    }

    // MARK: - Actions

    public static func setValue(_ element: AXUIElement, _ value: String) -> Bool {
        AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef) == .success
    }

    public static func performAction(_ element: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    public static func focus(_ element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, true as CFTypeRef) == .success
    }

    public static func closeWindow(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &value)
        guard result == .success, let closeButton = value else { return false }
        // swiftlint:disable:next force_cast
        return AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString) == .success
    }

    // MARK: - Search

    public static func findAll(_ element: AXUIElement, role targetRole: String, maxDepth: Int = 10, currentDepth: Int = 0) -> [AXUIElement] {
        guard currentDepth <= maxDepth else { return [] }
        var results: [AXUIElement] = []
        if role(element) == targetRole {
            results.append(element)
        }
        for child in children(element) {
            results += findAll(child, role: targetRole, maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }
        return results
    }

    public static func findFirst(_ element: AXUIElement, role targetRole: String, text: String, maxDepth: Int = 10, currentDepth: Int = 0) -> AXUIElement? {
        guard currentDepth <= maxDepth else { return nil }
        if role(element) == targetRole {
            let t = title(element) ?? value(element) ?? ""
            if t.localizedCaseInsensitiveContains(text) {
                return element
            }
        }
        for child in children(element) {
            if let found = findFirst(child, role: targetRole, text: text, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                return found
            }
        }
        return nil
    }

    public static func findFirst(_ element: AXUIElement, role targetRole: String, identifier targetId: String, maxDepth: Int = 10, currentDepth: Int = 0) -> AXUIElement? {
        guard currentDepth <= maxDepth else { return nil }
        if role(element) == targetRole {
            if identifier(element) == targetId {
                return element
            }
        }
        for child in children(element) {
            if let found = findFirst(child, role: targetRole, identifier: targetId, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                return found
            }
        }
        return nil
    }

    // MARK: - KakaoTalk Chat List

    public static func chatListTable(_ window: AXUIElement) -> AXUIElement? {
        for child in children(window) {
            if role(child) == "AXScrollArea" {
                for subchild in children(child) {
                    if role(subchild) == "AXTable" {
                        return subchild
                    }
                }
            }
        }
        return nil
    }

    public static func chatListScrollArea(_ window: AXUIElement) -> AXUIElement? {
        for child in children(window) {
            if role(child) == "AXScrollArea" {
                for subchild in children(child) {
                    if role(subchild) == "AXTable" {
                        return child
                    }
                }
            }
        }
        return nil
    }

    public static func findChatRow(_ table: AXUIElement, chatName: String, exact: Bool = false) -> AXUIElement? {
        for row in children(table) {
            guard role(row) == "AXRow" else { continue }
            for cell in children(row) {
                guard role(cell) == "AXCell" else { continue }
                for child in children(cell) {
                    if role(child) == "AXStaticText" && identifier(child) == "_NS:18" {
                        let name = value(child) ?? ""
                        let matches = exact ? name == chatName : name.localizedCaseInsensitiveContains(chatName)
                        if matches { return row }
                    }
                }
            }
        }
        return nil
    }

    public static func findSelfChatRow(_ table: AXUIElement) -> AXUIElement? {
        for row in children(table) {
            guard role(row) == "AXRow" else { continue }
            for cell in children(row) {
                guard role(cell) == "AXCell" else { continue }
                for child in children(cell) {
                    if role(child) == "AXImage" {
                        let desc = description(child) ?? ""
                        if desc.contains("badge me") { return row }
                    }
                }
            }
        }
        return nil
    }

    public static func selectRow(_ row: AXUIElement, in table: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(
            table,
            kAXSelectedRowsAttribute as CFString,
            [row] as CFTypeRef
        )
        return result == .success
    }

    // MARK: - Geometry

    public static func parent(_ element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value)
        guard result == .success else { return nil }
        // swiftlint:disable:next force_cast
        return (value as! AXUIElement)
    }

    public static func position(_ element: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        var point = CGPoint.zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    public static func size(_ element: AXUIElement) -> CGSize? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        var sz = CGSize.zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(axValue as! AXValue, .cgSize, &sz)
        return sz
    }

    // MARK: - Mouse

    public static func clickElement(_ element: AXUIElement) {
        guard let pos = position(element), let sz = size(element) else { return }
        let center = CGPoint(x: pos.x + sz.width / 2, y: pos.y + sz.height / 2)
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left),
           let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
            usleep(50000)
            mouseUp.post(tap: .cghidEventTap)
        }
    }

    public static func doubleClickElement(_ element: AXUIElement) {
        guard let pos = position(element), let sz = size(element) else { return }
        let center = CGPoint(x: pos.x + sz.width / 2, y: pos.y + sz.height / 2)
        for _ in 0..<2 {
            if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left),
               let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left) {
                mouseDown.setIntegerValueField(.mouseEventClickState, value: 2)
                mouseUp.setIntegerValueField(.mouseEventClickState, value: 2)
                mouseDown.post(tap: .cghidEventTap)
                usleep(20000)
                mouseUp.post(tap: .cghidEventTap)
                usleep(20000)
            }
        }
    }

    public static func moveMouse(to point: CGPoint) {
        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    public static func scroll(deltaY: Int32, at point: CGPoint? = nil) {
        if let point {
            moveMouse(to: point)
            usleep(50000)
        }
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: deltaY, wheel2: 0, wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }

    public static func scrollLines(deltaY: Int32, at point: CGPoint? = nil) {
        if let point {
            moveMouse(to: point)
            usleep(50000)
        }
        if let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: deltaY, wheel2: 0, wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }

    public static func scrollRowToVisible(_ row: AXUIElement, in scrollArea: AXUIElement) -> Bool {
        guard let rowPos = position(row), let rowSize = size(row),
              let areaPos = position(scrollArea), let areaSize = size(scrollArea) else {
            return false
        }
        let areaTop = areaPos.y
        let areaBottom = areaPos.y + areaSize.height
        if rowPos.y >= areaTop && (rowPos.y + rowSize.height) <= areaBottom { return true }

        let scrollCenter = CGPoint(x: areaPos.x + areaSize.width / 2, y: areaPos.y + areaSize.height / 2)
        for _ in 0..<80 {
            guard let curPos = position(row), let curH = size(row)?.height else { break }
            if curPos.y >= areaTop && (curPos.y + curH) <= areaBottom { return true }
            let deltaY: Int32 = curPos.y > areaBottom ? -3 : 3
            scrollLines(deltaY: deltaY, at: scrollCenter)
            usleep(50000)
        }
        if let finalPos = position(row), let finalSize = size(row) {
            return finalPos.y >= areaTop && (finalPos.y + finalSize.height) <= areaBottom
        }
        return false
    }

    // MARK: - Keyboard

    public static func typeText(_ text: String) {
        for char in text {
            let utf16 = Array(char.utf16)
            if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
               let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
                usleep(5000)
            }
        }
    }

    public static func pressKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        if let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
           let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            down.flags = flags
            up.flags = flags
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    public static func selectAll() {
        pressKey(keyCode: 0, flags: .maskCommand)
        Thread.sleep(forTimeInterval: 0.05)
    }

    // MARK: - Debug

    public static func dumpTree(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 6) -> String {
        guard depth <= maxDepth else { return "" }
        let indent = String(repeating: "  ", count: depth)
        let r = role(element) ?? "?"
        let t = title(element)
        let v = value(element)
        let d = description(element)
        let id = identifier(element)
        var line = "\(indent)[\(r)]"
        if let t { line += " title=\"\(t.prefix(60))\"" }
        if let v, !v.isEmpty { line += " value=\"\(v.prefix(60))\"" }
        if let d, !d.isEmpty { line += " desc=\"\(d.prefix(60))\"" }
        if let id, !id.isEmpty { line += " id=\"\(id)\"" }
        line += "\n"
        for child in children(element) {
            line += dumpTree(child, depth: depth + 1, maxDepth: maxDepth)
        }
        return line
    }
}

