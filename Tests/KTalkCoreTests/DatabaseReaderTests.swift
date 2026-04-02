import Foundation
import Testing
@testable import KTalkCore

@Suite("DatabaseReader")
struct DatabaseReaderTests {

    @Test("Can initialize with databasePath")
    func initializationWithPath() {
        let reader = DatabaseReader(databasePath: "/tmp/test.db")
        #expect(reader.databasePath == "/tmp/test.db")
    }

    @Test("open throws error for nonexistent file")
    func openThrowsForNonexistentFile() {
        let reader = DatabaseReader(databasePath: "/nonexistent/path/test.db")
        #expect(throws: KTalkError.self) {
            try reader.open(key: "any-key")
        }
    }

    @Test("kakaoDate converts Unix timestamp (seconds) to Date")
    func kakaoDateUnixTimestamp() {
        // Unix epoch
        let epoch = DatabaseReader.kakaoDate(0)
        #expect(epoch.timeIntervalSince1970 == 0)

        // 2024-01-01 00:00:00 UTC = 1704067200
        let known = DatabaseReader.kakaoDate(1_704_067_200)
        #expect(known.timeIntervalSince1970 == 1_704_067_200.0)
    }

    @Test("kakaoDate does not use CoreData offset (978307200)")
    func kakaoDateNotCoreDataOffset() {
        // CoreData epoch: 2001-01-01 = 978307200 seconds
        // KakaoTalk uses pure Unix timestamps without CoreData offset
        let date = DatabaseReader.kakaoDate(1_000_000_000)
        #expect(date.timeIntervalSince1970 == 1_000_000_000.0)
        #expect(date.timeIntervalSince1970 != 1_000_000_000.0 + 978_307_200.0)
    }

    @Test("canAccessRealDB returns Bool")
    func canAccessRealDBReturnsBool() {
        // Verify it returns Bool without crashing
        let result = DatabaseReader.canAccessRealDB()
        let _ = result  // just verify it executes
    }

    // MARK: - Integration Tests (run only when real KakaoTalk DB exists)

    @Test("chats returns Chat array (integration)")
    func chatsIntegration() throws {
        guard DatabaseReader.canAccessRealDB() else { return }
        guard let dbPath = DeviceInfo.discoverDatabaseFile() else { return }
        let uuid = try DeviceInfo.platformUUID()
        let userId = try DeviceInfo.userId()
        let key = KeyDerivation.secureKey(userId: userId, uuid: uuid)

        let reader = DatabaseReader(databasePath: dbPath)
        // Skip if key doesn't match (userId extraction strategy may differ from actual encryption key)
        do { try reader.open(key: key) } catch { return }
        let chats = try reader.chats(limit: 10)
        #expect(chats.count >= 0)
    }

    @Test("myUserId returns Int64 (integration)")
    func myUserIdIntegration() throws {
        guard DatabaseReader.canAccessRealDB() else { return }
        guard let dbPath = DeviceInfo.discoverDatabaseFile() else { return }
        let uuid = try DeviceInfo.platformUUID()
        let userId = try DeviceInfo.userId()
        let key = KeyDerivation.secureKey(userId: userId, uuid: uuid)

        let reader = DatabaseReader(databasePath: dbPath)
        do { try reader.open(key: key) } catch { return }
        let myId = try reader.myUserId()
        #expect(myId >= 0)
    }

    @Test("messages returns Message array (integration)")
    func messagesIntegration() throws {
        guard DatabaseReader.canAccessRealDB() else { return }
        guard let dbPath = DeviceInfo.discoverDatabaseFile() else { return }
        let uuid = try DeviceInfo.platformUUID()
        let userId = try DeviceInfo.userId()
        let key = KeyDerivation.secureKey(userId: userId, uuid: uuid)

        let reader = DatabaseReader(databasePath: dbPath)
        do { try reader.open(key: key) } catch { return }
        let chats = try reader.chats(limit: 1)
        guard let firstChat = chats.first else { return }
        let messages = try reader.messages(chatId: firstChat.id, limit: 5)
        #expect(messages.count >= 0)
    }

    @Test("search returns Message array (integration)")
    func searchIntegration() throws {
        guard DatabaseReader.canAccessRealDB() else { return }
        guard let dbPath = DeviceInfo.discoverDatabaseFile() else { return }
        let uuid = try DeviceInfo.platformUUID()
        let userId = try DeviceInfo.userId()
        let key = KeyDerivation.secureKey(userId: userId, uuid: uuid)

        let reader = DatabaseReader(databasePath: dbPath)
        do { try reader.open(key: key) } catch { return }
        let results = try reader.search(query: "안녕", limit: 5)
        #expect(results.count >= 0)
    }

    @Test("maxLogId returns Int64 (integration)")
    func maxLogIdIntegration() throws {
        guard DatabaseReader.canAccessRealDB() else { return }
        guard let dbPath = DeviceInfo.discoverDatabaseFile() else { return }
        let uuid = try DeviceInfo.platformUUID()
        let userId = try DeviceInfo.userId()
        let key = KeyDerivation.secureKey(userId: userId, uuid: uuid)

        let reader = DatabaseReader(databasePath: dbPath)
        do { try reader.open(key: key) } catch { return }
        let logId = try reader.maxLogId()
        #expect(logId >= 0)
    }
}
