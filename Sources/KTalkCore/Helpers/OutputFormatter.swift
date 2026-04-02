import Foundation

/// Text output format helpers.
public enum OutputFormatter {

    /// Returns a message formatted as "[YYYY-MM-DD HH:mm:ss] sender: text".
    public static func formatMessage(_ msg: Message) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeStr = formatter.string(from: msg.createdAt)

        let sender: String
        if msg.isFromMe {
            sender = "Me"
        } else {
            sender = msg.senderName ?? "Unknown"
        }

        let text = msg.text ?? "[\(msg.type)]"
        return "[\(timeStr)] \(sender): \(text)"
    }

    /// Returns a SyncMessage (watch message) formatted as "[YYYY-MM-DD HH:mm:ss] sender: text".
    public static func formatSyncMessage(_ msg: SyncMessage) -> String {
        let iso = ISO8601DateFormatter()
        let date = iso.date(from: msg.timestamp) ?? Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeStr = formatter.string(from: date)

        let sender = msg.isFromMe ? "Me" : (msg.senderName ?? "Unknown")
        let text = msg.text ?? "[type:\(msg.messageType)]"
        return "[\(timeStr)] \(sender): \(text)"
    }

    /// Returns a chat room formatted as "[ID] name (N members) last-message-time".
    public static func formatChat(_ chat: Chat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let lastTime = chat.lastMessageAt.map { " " + formatter.string(from: $0) } ?? ""
        let unread = chat.unreadCount > 0 ? " (\(chat.unreadCount) unread)" : ""
        return "[\(chat.id)] \(chat.displayName) (\(chat.memberCount) members)\(unread)\(lastTime)"
    }
}
