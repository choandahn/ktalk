import Foundation
import Testing
@testable import KTalkCore

@Suite("Error Tests")
struct ErrorTests {

    @Test("KTalkError conforms to LocalizedError")
    func conformsToLocalizedError() {
        let error: any LocalizedError = KTalkError.permissionDenied
        #expect(error.errorDescription != nil)
        #expect(!(error.errorDescription!.isEmpty))
    }

    @Test("permissionDenied message contains Full Disk Access")
    func permissionDeniedMentionsFullDiskAccess() {
        let error = KTalkError.permissionDenied
        #expect(error.errorDescription?.contains("Full Disk Access") == true)
    }

    @Test("invalidISODate message includes ISO 8601 format example")
    func invalidISODateIncludesFormatExample() {
        let error = KTalkError.invalidISODate("bad-date")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("ISO 8601") || desc.contains("ISO8601"))
        #expect(desc.contains("2025-"))
    }

    @Test("chatNotFound message includes chat ID")
    func chatNotFoundIncludesChatId() {
        let error = KTalkError.chatNotFound(12345)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("12345"))
    }

    @Test("invalidChatTarget case returns description")
    func invalidChatTargetHasDescription() {
        let error = KTalkError.invalidChatTarget("test-target")
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("appleScriptFailure case returns description")
    func appleScriptFailureHasDescription() {
        let error = KTalkError.appleScriptFailure("script error")
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("Existing error cases have errorDescription")
    func existingCasesHaveErrorDescription() {
        let errors: [KTalkError] = [
            .appNotInstalled,
            .databaseNotFound("/path"),
            .databaseOpenFailed("msg"),
            .sqlError("err"),
        ]
        for error in errors {
            #expect((error.errorDescription ?? "").isEmpty == false)
        }
    }
}
