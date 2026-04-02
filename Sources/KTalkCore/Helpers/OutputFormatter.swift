import Foundation

/// 텍스트 출력 포맷 헬퍼.
public enum OutputFormatter {

    /// 메시지를 "[YYYY-MM-DD HH:mm:ss] 발신자: 텍스트" 형식으로 반환합니다.
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

    /// SyncMessage(감시 메시지)를 "[YYYY-MM-DD HH:mm:ss] 발신자: 텍스트" 형식으로 반환합니다.
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

    /// 채팅방을 "[ID] 이름 (N명) 마지막메시지시간" 형식으로 반환합니다.
    public static func formatChat(_ chat: Chat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let lastTime = chat.lastMessageAt.map { " " + formatter.string(from: $0) } ?? ""
        let unread = chat.unreadCount > 0 ? " (\(chat.unreadCount) unread)" : ""
        return "[\(chat.id)] \(chat.displayName) (\(chat.memberCount)명)\(unread)\(lastTime)"
    }
}
