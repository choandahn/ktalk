import Foundation
import Testing
@testable import KTalkCore

@Suite("DatabaseWatcher Tests")
struct DatabaseWatcherTests {

    @Test("Can be instantiated and stopped")
    func initializationAndStop() {
        let watcher = DatabaseWatcher(databasePath: "/tmp/test.db", key: nil)
        watcher.stop()
    }

    @Test("stop() is safe to call before watch()")
    func stopBeforeWatch() {
        let watcher = DatabaseWatcher(databasePath: "/tmp/test.db", key: nil, pollInterval: 1.0)
        watcher.stop()
    }

    @Test("Custom pollInterval accepted")
    func customPollInterval() {
        let watcher = DatabaseWatcher(databasePath: "/tmp/test.db", key: "key", pollInterval: 5.0)
        watcher.stop()
    }

    @Test("startFromLogId is accepted")
    func startFromLogId() {
        let watcher = DatabaseWatcher(
            databasePath: "/tmp/test.db",
            key: nil,
            pollInterval: 2.0,
            startFromLogId: 42
        )
        watcher.stop()
    }

    @Test("SyncMessage is Encodable with snake_case keys")
    func syncMessageEncodable() throws {
        let msg = SyncMessage(
            type: "message",
            logId: 1,
            chatId: 2,
            chatName: "Test Chat",
            senderId: 3,
            senderName: "Alice",
            text: "Hello",
            messageType: 1,
            timestamp: "2025-01-01T00:00:00Z",
            isFromMe: false
        )
        let data = try JSONEncoder().encode(msg)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"log_id\""))
        #expect(json.contains("\"chat_id\""))
        #expect(json.contains("\"is_from_me\""))
        #expect(json.contains("\"message_type\""))
        #expect(json.contains("\"chat_name\""))
    }
}
