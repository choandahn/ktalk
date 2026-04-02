import Foundation
import Testing
@testable import KTalkCore

@Suite("Filter Tests")
struct FilterTests {

    @Test("유효한 ISO8601 문자열을 Date로 파싱한다")
    func parseValidISO8601() {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2025-01-15T10:30:00Z")
        #expect(date != nil)
    }

    @Test("ISO8601 날짜의 Unix 타임스탬프가 정확하다")
    func parseISO8601Timestamp() {
        var formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = formatter.date(from: "2025-01-15T10:30:00Z")
        // 2025-01-15T10:30:00Z = 1736937000
        #expect(date?.timeIntervalSince1970 == 1_736_937_000)
    }

    @Test("잘못된 ISO8601 문자열은 nil을 반환한다")
    func parseInvalidISO8601() {
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: "not-a-date") == nil)
        #expect(formatter.date(from: "") == nil)
        #expect(formatter.date(from: "2025-99-99") == nil)
    }

    @Test("DatabaseReader.messages는 start와 end Date 파라미터를 받는다")
    func messagesAcceptsStartEndParameters() {
        let reader = DatabaseReader(databasePath: "/nonexistent.db")
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        // DB가 없으므로 에러 발생 — 시그니처 존재 확인
        #expect(throws: KTalkError.self) {
            try reader.messages(chatId: 1, start: start, end: end, limit: 10)
        }
    }

    @Test("DatabaseReader.messages는 start만 지정해도 동작한다")
    func messagesAcceptsOnlyStart() {
        let reader = DatabaseReader(databasePath: "/nonexistent.db")
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(throws: KTalkError.self) {
            try reader.messages(chatId: 1, start: start, limit: 10)
        }
    }
}
