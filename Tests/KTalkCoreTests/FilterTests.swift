import Foundation
import Testing
@testable import KTalkCore

@Suite("Filter Tests")
struct FilterTests {

    @Test("Parses valid ISO8601 string to Date")
    func parseValidISO8601() {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: "2025-01-15T10:30:00Z")
        #expect(date != nil)
    }

    @Test("ISO8601 date Unix timestamp is accurate")
    func parseISO8601Timestamp() {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = formatter.date(from: "2025-01-15T10:30:00Z")
        // 2025-01-15T10:30:00Z = 1736937000
        #expect(date?.timeIntervalSince1970 == 1_736_937_000)
    }

    @Test("Invalid ISO8601 string returns nil")
    func parseInvalidISO8601() {
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: "not-a-date") == nil)
        #expect(formatter.date(from: "") == nil)
        #expect(formatter.date(from: "2025-99-99") == nil)
    }

    @Test("DatabaseReader.messages accepts start and end Date parameters")
    func messagesAcceptsStartEndParameters() {
        let reader = DatabaseReader(databasePath: "/nonexistent.db")
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = Date(timeIntervalSince1970: 1_800_000_000)
        // No DB available — verifies signature exists
        #expect(throws: KTalkError.self) {
            try reader.messages(chatId: 1, start: start, end: end, limit: 10)
        }
    }

    @Test("DatabaseReader.messages works with only start specified")
    func messagesAcceptsOnlyStart() {
        let reader = DatabaseReader(databasePath: "/nonexistent.db")
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(throws: KTalkError.self) {
            try reader.messages(chatId: 1, start: start, limit: 10)
        }
    }
}
