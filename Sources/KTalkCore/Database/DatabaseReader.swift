import CSQLCipher
import Foundation

/// Reads the KakaoTalk encrypted SQLite database using SQLCipher.
public final class DatabaseReader: @unchecked Sendable {
    private var db: OpaquePointer?
    public let databasePath: String

    public init(databasePath: String) {
        self.databasePath = databasePath
    }

    deinit {
        close()
    }

    /// Opens the database. Tries cipher compatibility modes 3 and 4 in order.
    public func open(key: String) throws {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            throw KTalkError.databaseNotFound(databasePath)
        }

        let compatModes = [3, 4]
        for compat in compatModes {
            if db != nil { sqlite3_close(db); db = nil }

            let result = sqlite3_open_v2(
                databasePath, &db,
                SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil
            )
            guard result == SQLITE_OK else {
                let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
                throw KTalkError.databaseOpenFailed(msg)
            }

            do {
                try exec("PRAGMA cipher_default_compatibility = \(compat)")
                try exec("PRAGMA KEY='\(key)'")
                try exec("SELECT count(*) FROM sqlite_master")
                return  // success
            } catch {
                continue
            }
        }

        throw KTalkError.databaseOpenFailed(
            "PRAGMA key failed for all cipher compatibility modes — " +
            "the database is encrypted and the key is wrong, or SQLCipher is not linked. " +
            "Install: brew install sqlcipher"
        )
    }

    public func close() {
        if let db { sqlite3_close(db) }
        db = nil
    }

    // MARK: - Queries

    /// Returns the list of chat rooms.
    public func chats(limit: Int = 50) throws -> [Chat] {
        let sql = """
            SELECT r.chatId, r.type, r.chatName, r.activeMembersCount,
                   r.lastLogId, r.lastUpdatedAt, r.countOfNewMessage,
                   u.displayName, u.friendNickName, u.nickName
            FROM NTChatRoom r
            LEFT JOIN NTUser u ON r.directChatMemberUserId = u.userId AND u.linkId = 0
            ORDER BY r.lastUpdatedAt DESC
            LIMIT ?
            """
        return try query(sql, bind: [.int(limit)]) { row in
            let chatName = row.string(2)
            let displayName = row.string(7) ?? row.string(8) ?? row.string(9)
            let name = chatName ?? displayName ?? "(unknown)"

            return Chat(
                id: row.int64(0),
                type: Chat.ChatType.from(rawInt: row.int(1)),
                displayName: name,
                memberCount: row.int(3),
                lastMessageId: row.optionalInt64(4),
                lastMessageAt: row.optionalKakaoDate(5),
                unreadCount: row.int(6)
            )
        }
    }

    /// Returns messages for a specific chat room.
    public func messages(chatId: Int64, since: Date? = nil, start: Date? = nil, end: Date? = nil, limit: Int = 50) throws -> [Message] {
        var conditions = ["m.chatId = ?"]
        var bindings: [SQLValue] = [.int64(chatId)]

        if let since {
            conditions.append("m.sentAt >= ?")
            bindings.append(.int64(Int64(since.timeIntervalSince1970)))
        }

        if let start {
            conditions.append("m.sentAt >= ?")
            bindings.append(.int64(Int64(start.timeIntervalSince1970)))
        }

        if let end {
            conditions.append("m.sentAt <= ?")
            bindings.append(.int64(Int64(end.timeIntervalSince1970)))
        }

        let whereClause = "WHERE " + conditions.joined(separator: " AND ")
        let sql = """
            SELECT m.logId, m.chatId, m.authorId,
                   COALESCE(u.displayName, u.friendNickName, u.nickName) as senderName,
                   m.message, m.type, m.sentAt
            FROM NTChatMessage m
            LEFT JOIN NTUser u ON m.authorId = u.userId AND u.linkId = 0
            \(whereClause)
            ORDER BY m.sentAt DESC
            LIMIT ?
            """
        bindings.append(.int(limit))

        let myId = try myUserId()
        return try query(sql, bind: bindings) { row in
            Message(
                id: row.int64(0),
                chatId: row.int64(1),
                senderId: row.int64(2),
                senderName: row.string(3),
                text: row.string(4),
                type: Message.MessageType(rawValue: row.int(5)),
                createdAt: row.kakaoDate(6),
                isFromMe: row.int64(2) == myId
            )
        }
    }

    /// Full-text message search.
    public func search(query searchQuery: String, limit: Int = 20) throws -> [Message] {
        let sql = """
            SELECT m.logId, m.chatId, m.authorId,
                   COALESCE(u.displayName, u.friendNickName, u.nickName) as senderName,
                   m.message, m.type, m.sentAt
            FROM NTChatMessage m
            LEFT JOIN NTUser u ON m.authorId = u.userId AND u.linkId = 0
            WHERE m.message LIKE ?
            ORDER BY m.sentAt DESC
            LIMIT ?
            """
        let myId = try myUserId()
        return try query(sql, bind: [.string("%\(searchQuery)%"), .int(limit)]) { row in
            Message(
                id: row.int64(0),
                chatId: row.int64(1),
                senderId: row.int64(2),
                senderName: row.string(3),
                text: row.string(4),
                type: Message.MessageType(rawValue: row.int(5)),
                createdAt: row.kakaoDate(6),
                isFromMe: row.int64(2) == myId
            )
        }
    }

    /// Retrieves the logged-in user's ID from NTChatContext.
    public func myUserId() throws -> Int64 {
        let results = try query("SELECT userId FROM NTChatContext LIMIT 1", bind: []) { row in
            row.int64(0)
        }
        return results.first ?? 0
    }

    /// Returns messages after the given logId along with chat room names (for sync/watching).
    public func messagesSinceLogId(_ logId: Int64, limit: Int = 100) throws -> [(message: Message, chatName: String?)] {
        let sql = """
            SELECT m.logId, m.chatId,
                   COALESCE(r.chatName, u.displayName, u.friendNickName, u.nickName) as chatName,
                   m.authorId,
                   COALESCE(u2.displayName, u2.friendNickName, u2.nickName) as senderName,
                   m.message, m.type, m.sentAt
            FROM NTChatMessage m
            LEFT JOIN NTChatRoom r ON m.chatId = r.chatId
            LEFT JOIN NTUser u ON r.directChatMemberUserId = u.userId AND u.linkId = 0
            LEFT JOIN NTUser u2 ON m.authorId = u2.userId AND u2.linkId = 0
            WHERE m.logId > ?
            ORDER BY m.logId ASC
            LIMIT ?
            """
        let myId = try myUserId()
        return try query(sql, bind: [.int64(logId), .int(limit)]) { row in
            let message = Message(
                id: row.int64(0),
                chatId: row.int64(1),
                senderId: row.int64(3),
                senderName: row.string(4),
                text: row.string(5),
                type: Message.MessageType(rawValue: row.int(6)),
                createdAt: row.kakaoDate(7),
                isFromMe: row.int64(3) == myId
            )
            return (message: message, chatName: row.string(2))
        }
    }

    /// Returns the maximum logId from the message table.
    public func maxLogId() throws -> Int64 {
        let results = try query("SELECT MAX(logId) FROM NTChatMessage", bind: []) { row in
            row.optionalInt64(0)
        }
        return results.first.flatMap { $0 } ?? 0
    }

    /// Executes a raw SQL query and returns results as an array of dictionaries.
    public func rawQuery(_ sql: String) throws -> [[String: String]] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw KTalkError.sqlError("prepare: \(msg)")
        }
        defer { sqlite3_finalize(stmt) }

        let columnCount = sqlite3_column_count(stmt)
        var results: [[String: String]] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: String] = [:]
            for i in 0..<columnCount {
                let colName = String(cString: sqlite3_column_name(stmt, i))
                if let ptr = sqlite3_column_text(stmt, i) {
                    row[colName] = String(cString: ptr)
                } else {
                    row[colName] = ""
                }
            }
            results.append(row)
        }
        return results
    }

    /// Returns the list of SQL strings for the database schema.
    public func schema() throws -> [String] {
        try query(
            "SELECT sql FROM sqlite_master WHERE type='table' ORDER BY name",
            bind: []
        ) { row in
            row.string(0) ?? ""
        }
    }

    // MARK: - Static Helpers

    /// Converts a KakaoTalk timestamp (Unix seconds) to Date.
    /// Note: Does not use the CoreData offset (978307200).
    public static func kakaoDate(_ timestamp: Int64) -> Date {
        Date(timeIntervalSince1970: Double(timestamp))
    }

    /// Checks whether the real KakaoTalk DB is accessible.
    public static func canAccessRealDB() -> Bool {
        DeviceInfo.discoverDatabaseFile() != nil
    }

    // MARK: - SQLite Helpers

    enum SQLValue {
        case int(Int)
        case int64(Int64)
        case double(Double)
        case string(String)
        case null
    }

    private func exec(_ sql: String) throws {
        var errMsg: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if result != SQLITE_OK {
            let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errMsg)
            throw KTalkError.sqlError(msg)
        }
    }

    private func query<T>(_ sql: String, bind: [SQLValue], transform: (Row) -> T) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw KTalkError.sqlError("prepare: \(msg)")
        }
        defer { sqlite3_finalize(stmt) }

        for (i, value) in bind.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case .int(let v): sqlite3_bind_int(stmt, idx, Int32(v))
            case .int64(let v): sqlite3_bind_int64(stmt, idx, v)
            case .double(let v): sqlite3_bind_double(stmt, idx, v)
            case .string(let v):
                sqlite3_bind_text(stmt, idx, v, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .null: sqlite3_bind_null(stmt, idx)
            }
        }

        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(transform(Row(stmt: stmt!)))
        }
        return results
    }

    struct Row {
        let stmt: OpaquePointer

        func int(_ col: Int32) -> Int {
            Int(sqlite3_column_int(stmt, col))
        }

        func int64(_ col: Int32) -> Int64 {
            sqlite3_column_int64(stmt, col)
        }

        func optionalInt64(_ col: Int32) -> Int64? {
            sqlite3_column_type(stmt, col) == SQLITE_NULL ? nil : int64(col)
        }

        func string(_ col: Int32) -> String? {
            guard let ptr = sqlite3_column_text(stmt, col) else { return nil }
            return String(cString: ptr)
        }

        func bool(_ col: Int32) -> Bool {
            sqlite3_column_int(stmt, col) != 0
        }

        func kakaoDate(_ col: Int32) -> Date {
            DatabaseReader.kakaoDate(sqlite3_column_int64(stmt, col))
        }

        func optionalKakaoDate(_ col: Int32) -> Date? {
            let val = sqlite3_column_int64(stmt, col)
            return val == 0 ? nil : DatabaseReader.kakaoDate(val)
        }
    }
}

// MARK: - Chat.ChatType Extension

extension Chat.ChatType {
    static func from(rawInt: Int) -> Self {
        switch rawInt {
        case 0: return .direct
        case 1: return .group
        default: return .unknown
        }
    }
}
