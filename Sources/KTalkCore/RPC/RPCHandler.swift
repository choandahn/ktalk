import Foundation

/// JSON-RPC 2.0 메서드 라우터 및 실행기.
/// handleRequest()에서 요청을 파싱하고 적절한 메서드로 라우팅합니다.
public final class RPCHandler: @unchecked Sendable {
    private let databasePath: String?
    private let notifyCallback: @Sendable (Data) -> Void
    private var watcher: DatabaseWatcher?
    private var watchThread: Thread?

    /// - Parameters:
    ///   - databasePath: DB 파일 경로 (nil이면 자동 감지)
    ///   - notifyCallback: watch.subscribe 알림을 출력할 콜백 (JSON Lines)
    public init(databasePath: String?, notifyCallback: @escaping @Sendable (Data) -> Void) {
        self.databasePath = databasePath
        self.notifyCallback = notifyCallback
    }

    /// JSON-RPC 요청 Data를 처리하고 응답 Data를 반환합니다.
    public func handleRequest(_ data: Data) -> Data {
        do {
            let req = try JSONRPCProtocol.parseRequest(data)
            return try route(req)
        } catch let e as JSONRPCParseError {
            let code: RPCErrorCode = (e == .invalidJSON) ? .parseError : .invalidRequest
            return (try? JSONRPCProtocol.errorResponse(code: code, id: nil)) ?? Data()
        } catch {
            return (try? JSONRPCProtocol.errorResponse(code: .internalError, id: nil)) ?? Data()
        }
    }

    // MARK: - Private routing

    private func route(_ req: JSONRPCRequest) throws -> Data {
        switch req.method {
        case "chats.list":
            return try handleChatsList(req)
        case "messages.history":
            return try handleMessagesHistory(req)
        case "send":
            return try handleSend(req)
        case "watch.subscribe":
            return try handleWatchSubscribe(req)
        case "watch.unsubscribe":
            return try handleWatchUnsubscribe(req)
        default:
            return try JSONRPCProtocol.errorResponse(code: .methodNotFound, id: req.id)
        }
    }

    // MARK: - Method handlers

    private func handleChatsList(_ req: JSONRPCRequest) throws -> Data {
        let limit = req.params?["limit"] as? Int ?? 50
        let reader = try openReader()
        defer { reader.close() }
        let chats = try reader.chats(limit: limit)
        let encoder = makeEncoder()
        let resultData = try encoder.encode(chats)
        let result = try JSONSerialization.jsonObject(with: resultData)
        let response = JSONRPCResponse(result: result, error: nil, id: req.id)
        return try JSONRPCProtocol.serializeResponse(response)
    }

    private func handleMessagesHistory(_ req: JSONRPCRequest) throws -> Data {
        guard let chatIdRaw = req.params?["chat_id"] else {
            return try JSONRPCProtocol.errorResponse(code: .invalidParams, id: req.id)
        }
        let chatId: Int64
        if let v = chatIdRaw as? Int64 {
            chatId = v
        } else if let v = chatIdRaw as? Int {
            chatId = Int64(v)
        } else {
            return try JSONRPCProtocol.errorResponse(code: .invalidParams, id: req.id)
        }

        let limit = req.params?["limit"] as? Int ?? 50
        var since: Date? = nil
        if let sinceStr = req.params?["since"] as? String {
            since = ISO8601DateFormatter().date(from: sinceStr)
        }

        let reader = try openReader()
        defer { reader.close() }
        let messages = try reader.messages(chatId: chatId, since: since, limit: limit)
        let encoder = makeEncoder()
        let resultData = try encoder.encode(messages)
        let result = try JSONSerialization.jsonObject(with: resultData)
        let response = JSONRPCResponse(result: result, error: nil, id: req.id)
        return try JSONRPCProtocol.serializeResponse(response)
    }

    private func handleSend(_ req: JSONRPCRequest) throws -> Data {
        guard let to = req.params?["to"] as? String,
              let text = req.params?["text"] as? String else {
            return try JSONRPCProtocol.errorResponse(code: .invalidParams, id: req.id)
        }
        let selfChat = req.params?["self_chat"] as? Bool ?? false
        let automator = KakaoAutomator()
        try automator.sendMessage(to: to, message: text, selfChat: selfChat)
        let response = JSONRPCResponse(result: ["ok": true], error: nil, id: req.id)
        return try JSONRPCProtocol.serializeResponse(response)
    }

    private func handleWatchSubscribe(_ req: JSONRPCRequest) throws -> Data {
        // 이미 감시 중이면 중지 후 재시작
        stopWatcher()

        let filterChatId = req.params?["chat_id"] as? Int64
            ?? (req.params?["chat_id"] as? Int).map(Int64.init)
        let interval = req.params?["interval"] as? Double ?? 2.0

        let (path, key) = try resolvePathAndKey()
        let watcher = DatabaseWatcher(databasePath: path, key: key, pollInterval: interval)
        self.watcher = watcher

        let callback: @Sendable (Data) -> Void = notifyCallback
        let thread = Thread {
            watcher.watch(
                onMessages: { messages in
                    for msg in messages {
                        if let filter = filterChatId, msg.chatId != filter { continue }
                        let encoder = JSONEncoder()
                        encoder.outputFormatting = [.sortedKeys]
                        guard let msgData = try? encoder.encode(msg),
                              let msgObj = try? JSONSerialization.jsonObject(with: msgData) else { continue }
                        let notification = JSONRPCNotification(
                            method: "watch.message",
                            params: msgObj as? [String: Any]
                        )
                        if let notifData = try? JSONRPCProtocol.serializeNotification(notification) {
                            callback(notifData)
                        }
                    }
                },
                onError: { _ in }
            )
        }
        thread.start()
        self.watchThread = thread

        let response = JSONRPCResponse(result: ["subscribed": true], error: nil, id: req.id)
        return try JSONRPCProtocol.serializeResponse(response)
    }

    private func handleWatchUnsubscribe(_ req: JSONRPCRequest) throws -> Data {
        stopWatcher()
        let response = JSONRPCResponse(result: ["unsubscribed": true], error: nil, id: req.id)
        return try JSONRPCProtocol.serializeResponse(response)
    }

    // MARK: - Helpers

    private func stopWatcher() {
        watcher?.stop()
        watcher = nil
        watchThread = nil
    }

    private func openReader() throws -> DatabaseReader {
        let (path, key) = try resolvePathAndKey()
        let reader = DatabaseReader(databasePath: path)
        if let key {
            try reader.open(key: key)
        } else {
            throw KTalkError.databaseOpenFailed("암호화 키를 찾을 수 없습니다")
        }
        return reader
    }

    private func resolvePathAndKey() throws -> (path: String, key: String?) {
        if let path = databasePath {
            return (path, nil)
        }
        let uuid = try DeviceInfo.platformUUID()
        if let uid = try? DeviceInfo.userId() {
            let dbName = KeyDerivation.databaseName(userId: uid, uuid: uuid)
            let candidates = [
                "\(DeviceInfo.containerPath)/\(dbName)",
                "\(DeviceInfo.containerPath)/\(dbName).db",
            ]
            if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                return (found, KeyDerivation.secureKey(userId: uid, uuid: uuid))
            }
        }
        guard let path = DeviceInfo.discoverDatabaseFile() else {
            let uid = try DeviceInfo.userId()
            let dbName = KeyDerivation.databaseName(userId: uid, uuid: uuid)
            throw KTalkError.databaseNotFound("\(DeviceInfo.containerPath)/\(dbName)")
        }
        var candidateIds = (try? DeviceInfo.userId()).map { [$0] } ?? []
        candidateIds += DeviceInfo.candidateUserIds().filter { !candidateIds.contains($0) }
        for uid in candidateIds {
            let key = KeyDerivation.secureKey(userId: uid, uuid: uuid)
            let reader = DatabaseReader(databasePath: path)
            if (try? reader.open(key: key)) != nil {
                reader.close()
                return (path, key)
            }
        }
        return (path, nil)
    }

    private func makeEncoder() -> JSONEncoder {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return enc
    }
}
