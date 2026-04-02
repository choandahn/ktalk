import Foundation

/// A KakaoTalk message.
public struct Message: Codable, Sendable {
    public let id: Int64
    public let chatId: Int64
    public let senderId: Int64
    public let senderName: String?
    public let text: String?
    public let type: MessageType
    public let createdAt: Date
    public let isFromMe: Bool

    public init(
        id: Int64,
        chatId: Int64,
        senderId: Int64,
        senderName: String?,
        text: String?,
        type: MessageType,
        createdAt: Date,
        isFromMe: Bool
    ) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.type = type
        self.createdAt = createdAt
        self.isFromMe = isFromMe
    }

    public enum MessageType: Int, Sendable {
        case system = 0
        case text = 1
        case photo = 2
        case video = 3
        case voice = 4
        case sticker = 5
        case file = 6
        case location = 7
        case unknown = -1

        public init(rawValue: Int) {
            switch rawValue {
            case 0: self = .system
            case 1: self = .text
            case 2: self = .photo
            case 3: self = .video
            case 4: self = .voice
            case 5: self = .sticker
            case 6: self = .file
            case 7: self = .location
            default: self = .unknown
            }
        }
    }
}

extension Message.MessageType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        self = Message.MessageType(rawValue: rawValue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
