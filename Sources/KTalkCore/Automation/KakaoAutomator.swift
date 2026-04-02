import AppKit
import ApplicationServices
import Foundation

/// Automates the KakaoTalk UI to send messages.
public struct KakaoAutomator: Sendable {

    public static let bundleId = "com.kakao.KakaoTalkMac"

    public init() {}

    public func sendMessage(to chatName: String, message: String, selfChat: Bool = false) throws {
        // 1. Launch KakaoTalk and verify login
        let stateBefore = AppLifecycle.detectState()
        try AppLifecycle.ensureReady(credentials: CredentialStore())
        if stateBefore != .loggedIn {
            Thread.sleep(forTimeInterval: 2.0)
        }

        // 2. Activate and acquire app element
        try AXHelpers.activateApp(bundleId: Self.bundleId)
        let app = try AXHelpers.appElement(bundleId: Self.bundleId)

        let windows = AXHelpers.windows(app)
        guard let mainWindow = windows.first(where: { AXHelpers.identifier($0) == "Main Window" }) else {
            throw AutomationError.noWindows
        }

        // 3. Close existing chat windows
        for w in windows where AXHelpers.identifier(w) != "Main Window" {
            _ = AXHelpers.closeWindow(w)
        }
        if windows.count > 1 {
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 4. Switch to chat tab
        if let chatroomsTab = AXHelpers.findFirst(mainWindow, role: "AXCheckBox", identifier: "chatrooms") {
            _ = AXHelpers.performAction(chatroomsTab, kAXPressAction as String)
            Thread.sleep(forTimeInterval: 0.3)
        }

        // 5. Find chat room row
        guard let table = AXHelpers.chatListTable(mainWindow) else {
            throw AutomationError.chatNotFound(chatName)
        }

        let row: AXUIElement
        if selfChat {
            guard let selfRow = AXHelpers.findSelfChatRow(table) else {
                throw AutomationError.chatNotFound("self-chat")
            }
            row = selfRow
        } else {
            guard let chatRow = AXHelpers.findChatRow(table, chatName: chatName) else {
                throw AutomationError.chatNotFound(chatName)
            }
            row = chatRow
        }

        // 6. Select row and open chat window with Enter
        var opened = false
        if AXHelpers.selectRow(row, in: table) {
            Thread.sleep(forTimeInterval: 0.2)
            AXHelpers.pressKey(keyCode: 36) // Enter
            Thread.sleep(forTimeInterval: 0.5)
            let checkWindows = AXHelpers.windows(app)
            opened = checkWindows.contains { AXHelpers.identifier($0) != "Main Window" }
        }
        if !opened {
            if let scrollArea = AXHelpers.chatListScrollArea(mainWindow) {
                _ = AXHelpers.scrollRowToVisible(row, in: scrollArea)
                Thread.sleep(forTimeInterval: 0.3)
            }
            AXHelpers.doubleClickElement(row)
        }

        // 7. Wait for chat window
        var chatWindow: AXUIElement?
        let windowDeadline = Date().addingTimeInterval(5.0)
        while Date() < windowDeadline {
            Thread.sleep(forTimeInterval: 0.5)
            let updatedWindows = AXHelpers.windows(app)
            chatWindow = updatedWindows.first(where: { AXHelpers.identifier($0) != "Main Window" })
            if chatWindow != nil { break }
        }
        guard let chatWindow else {
            throw AutomationError.inputFieldNotFound
        }

        // 8. Find input field (AXTextArea inside AXScrollArea without AXTable)
        guard let inputField = findInputField(in: chatWindow) else {
            throw AutomationError.inputFieldNotFound
        }

        // 9. Enter message
        _ = AXHelpers.performAction(chatWindow, kAXRaiseAction as String)
        Thread.sleep(forTimeInterval: 0.3)
        AXHelpers.clickElement(inputField)
        Thread.sleep(forTimeInterval: 0.3)

        if AXHelpers.setValue(inputField, message) {
            Thread.sleep(forTimeInterval: 0.2)
            AXHelpers.pressKey(keyCode: 36) // Return
        } else {
            _ = AXHelpers.focus(inputField)
            Thread.sleep(forTimeInterval: 0.1)
            AXHelpers.typeText(message)
            Thread.sleep(forTimeInterval: 0.2)
            AXHelpers.pressKey(keyCode: 36) // Return
        }

        // 10. Close chat window
        Thread.sleep(forTimeInterval: 0.3)
        _ = AXHelpers.closeWindow(chatWindow)
    }

    private func findInputField(in window: AXUIElement) -> AXUIElement? {
        for child in AXHelpers.children(window) {
            guard AXHelpers.role(child) == "AXScrollArea" else { continue }
            let hasTable = AXHelpers.children(child).contains { AXHelpers.role($0) == "AXTable" }
            if !hasTable {
                for subchild in AXHelpers.children(child) {
                    if AXHelpers.role(subchild) == "AXTextArea" {
                        return subchild
                    }
                }
            }
        }
        return nil
    }
}

public enum AutomationError: Error, CustomStringConvertible {
    case noWindows
    case chatNotFound(String)
    case inputFieldNotFound
    case sendFailed(String)

    public var description: String {
        switch self {
        case .noWindows:
            return "KakaoTalk has no open windows"
        case .chatNotFound(let name):
            return "Chat '\(name)' not found in the chat list"
        case .inputFieldNotFound:
            return "Could not find the message input field"
        case .sendFailed(let msg):
            return "Failed to send message: \(msg)"
        }
    }
}
