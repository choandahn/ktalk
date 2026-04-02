import Foundation

/// KakaoTalk 데이터베이스를 폴링하여 새 메시지를 감시합니다.
/// logId 기반 high-water mark로 중복 없이 새 메시지만 전달합니다.
public final class DatabaseWatcher: @unchecked Sendable {
    private let databasePath: String
    private let key: String?
    private let pollInterval: TimeInterval
    private var lastLogId: Int64
    private var running = false

    public init(
        databasePath: String,
        key: String?,
        pollInterval: TimeInterval = 2.0,
        startFromLogId: Int64? = nil
    ) {
        self.databasePath = databasePath
        self.key = key
        self.pollInterval = pollInterval
        self.lastLogId = startFromLogId ?? 0
    }

    /// 새 메시지 감시를 시작합니다. stop() 호출 전까지 블로킹합니다.
    public func watch(
        onMessages: @escaping ([SyncMessage]) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        running = true

        // 시작 logId가 없으면 현재 최대값으로 초기화
        if lastLogId == 0 {
            do {
                lastLogId = try fetchMaxLogId()
            } catch {
                onError(error)
                return
            }
        }

        while running {
            do {
                let messages = try fetchNewMessages()
                if !messages.isEmpty {
                    if let maxId = messages.map(\.logId).max() {
                        lastLogId = maxId
                    }
                    onMessages(messages)
                }
            } catch {
                onError(error)
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }

    public func stop() {
        running = false
    }

    // MARK: - Private

    private func openReader() throws -> DatabaseReader {
        guard let key else {
            throw KTalkError.databaseOpenFailed("암호화 키가 필요합니다")
        }
        let reader = DatabaseReader(databasePath: databasePath)
        try reader.open(key: key)
        return reader
    }

    private func fetchMaxLogId() throws -> Int64 {
        let reader = try openReader()
        defer { reader.close() }
        return try reader.maxLogId()
    }

    private func fetchNewMessages() throws -> [SyncMessage] {
        let reader = try openReader()
        defer { reader.close() }

        let isoFormatter = ISO8601DateFormatter()
        let results = try reader.messagesSinceLogId(lastLogId)

        return results.map { item in
            SyncMessage(
                type: "message",
                logId: item.message.id,
                chatId: item.message.chatId,
                chatName: item.chatName,
                senderId: item.message.senderId,
                senderName: item.message.senderName,
                text: item.message.text,
                messageType: item.message.type.rawValue,
                timestamp: isoFormatter.string(from: item.message.createdAt),
                isFromMe: item.message.isFromMe
            )
        }
    }
}

/// 감시자가 전달하는 메시지 이벤트 (JSON 직렬화용).
public struct SyncMessage: Sendable, Encodable {
    public let type: String
    public let logId: Int64
    public let chatId: Int64
    public let chatName: String?
    public let senderId: Int64
    public let senderName: String?
    public let text: String?
    public let messageType: Int
    public let timestamp: String
    public let isFromMe: Bool

    public init(
        type: String,
        logId: Int64,
        chatId: Int64,
        chatName: String?,
        senderId: Int64,
        senderName: String?,
        text: String?,
        messageType: Int,
        timestamp: String,
        isFromMe: Bool
    ) {
        self.type = type
        self.logId = logId
        self.chatId = chatId
        self.chatName = chatName
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.messageType = messageType
        self.timestamp = timestamp
        self.isFromMe = isFromMe
    }

    enum CodingKeys: String, CodingKey {
        case type
        case logId = "log_id"
        case chatId = "chat_id"
        case chatName = "chat_name"
        case senderId = "sender_id"
        case senderName = "sender"
        case text
        case messageType = "message_type"
        case timestamp
        case isFromMe = "is_from_me"
    }
}
