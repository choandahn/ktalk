import Foundation
import Testing
@testable import KTalkCore

@Suite("DurationParser Tests")
struct DurationParserTests {

    @Test("1h = 3600 seconds")
    func oneHour() {
        #expect(DurationParser.parse("1h") == 3600)
    }

    @Test("24h = 86400 seconds")
    func twentyFourHours() {
        #expect(DurationParser.parse("24h") == 86400)
    }

    @Test("7d = 604800 seconds")
    func sevenDays() {
        #expect(DurationParser.parse("7d") == 604800)
    }

    @Test("30m = 1800 seconds")
    func thirtyMinutes() {
        #expect(DurationParser.parse("30m") == 1800)
    }

    @Test("250ms = 0.25 seconds")
    func twoFiftyMilliseconds() {
        #expect(DurationParser.parse("250ms") == 0.25)
    }

    @Test("1s = 1 second")
    func oneSecond() {
        #expect(DurationParser.parse("1s") == 1)
    }

    @Test("2m = 120 seconds")
    func twoMinutes() {
        #expect(DurationParser.parse("2m") == 120)
    }

    @Test("invalid returns nil")
    func invalidReturnsNil() {
        #expect(DurationParser.parse("invalid") == nil)
        #expect(DurationParser.parse("") == nil)
        #expect(DurationParser.parse("abc") == nil)
    }
}
