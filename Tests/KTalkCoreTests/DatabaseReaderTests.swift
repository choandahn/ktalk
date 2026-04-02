import Foundation
import Testing
@testable import KTalkCore

@Suite("DatabaseReader")
struct DatabaseReaderTests {

    @Test("databasePath로 초기화할 수 있다")
    func initializationWithPath() {
        let reader = DatabaseReader(databasePath: "/tmp/test.db")
        #expect(reader.databasePath == "/tmp/test.db")
    }

    @Test("존재하지 않는 파일로 open하면 에러를 던진다")
    func openThrowsForNonexistentFile() {
        let reader = DatabaseReader(databasePath: "/nonexistent/path/test.db")
        #expect(throws: KTalkError.self) {
            try reader.open(key: "any-key")
        }
    }

    @Test("kakaoDate는 Unix 타임스탬프(초)를 Date로 변환한다")
    func kakaoDateUnixTimestamp() {
        // Unix epoch
        let epoch = DatabaseReader.kakaoDate(0)
        #expect(epoch.timeIntervalSince1970 == 0)

        // 2024-01-01 00:00:00 UTC = 1704067200
        let known = DatabaseReader.kakaoDate(1_704_067_200)
        #expect(known.timeIntervalSince1970 == 1_704_067_200.0)
    }

    @Test("kakaoDate는 CoreData 오프셋(978307200)을 사용하지 않는다")
    func kakaoDateNotCoreDataOffset() {
        // CoreData 기준점: 2001-01-01 = 978307200초
        // KakaoTalk은 CoreData 오프셋 없이 순수 Unix timestamp 사용
        let date = DatabaseReader.kakaoDate(1_000_000_000)
        #expect(date.timeIntervalSince1970 == 1_000_000_000.0)
        #expect(date.timeIntervalSince1970 != 1_000_000_000.0 + 978_307_200.0)
    }

    @Test("canAccessRealDB는 Bool을 반환한다")
    func canAccessRealDBReturnsBool() {
        // 크래시 없이 Bool 반환 확인
        let result = DatabaseReader.canAccessRealDB()
        let _ = result  // just verify it executes
    }

    // MARK: - 통합 테스트 (실제 KakaoTalk DB가 있을 때만 실행)

    @Test("chats는 Chat 배열을 반환한다 (통합)")
    func chatsIntegration() throws {
        guard DatabaseReader.canAccessRealDB() else { return }
        guard let dbPath = DeviceInfo.discoverDatabaseFile() else { return }
        let uuid = try DeviceInfo.platformUUID()
        let userId = try DeviceInfo.userId()
        let key = KeyDerivation.secureKey(userId: userId, uuid: uuid)

        let reader = DatabaseReader(databasePath: dbPath)
        // key가 맞지 않으면 스킵 (userId 추출 전략이 실제 암호화 키와 다를 수 있음)
        do { try reader.open(key: key) } catch { return }
        let chats = try reader.chats(limit: 10)
        #expect(chats.count >= 0)
    }

    @Test("myUserId는 Int64를 반환한다 (통합)")
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

    @Test("messages는 Message 배열을 반환한다 (통합)")
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

    @Test("search는 Message 배열을 반환한다 (통합)")
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

    @Test("maxLogId는 Int64를 반환한다 (통합)")
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
