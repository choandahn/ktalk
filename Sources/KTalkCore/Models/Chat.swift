import Foundation

/// A KakaoTalk chat room.
public struct Chat: Codable, Sendable {
    public let id: Int64
    public let type: ChatType
    public let displayName: String
    public let memberCount: Int
    public let lastMessageId: Int64?
    public let lastMessageAt: Date?
    public let unreadCount: Int

    public init(
        id: Int64,
        type: ChatType,
        displayName: String,
        memberCount: Int,
        lastMessageId: Int64?,
        lastMessageAt: Date?,
        unreadCount: Int
    ) {
        self.id = id
        self.type = type
        self.displayName = displayName
        self.memberCount = memberCount
        self.lastMessageId = lastMessageId
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
    }

    public enum ChatType: String, Codable, Sendable {
        case direct = "direct"
        case group = "group"
        case openChat = "open"
        case unknown = "unknown"
    }
}
