import Foundation
import Testing
@testable import KTalkCore

@Suite("Error Tests")
struct ErrorTests {

    @Test("KTalkError는 LocalizedError를 따른다")
    func conformsToLocalizedError() {
        let error: any LocalizedError = KTalkError.permissionDenied
        #expect(error.errorDescription != nil)
        #expect(!(error.errorDescription!.isEmpty))
    }

    @Test("permissionDenied 메시지에 Full Disk Access가 포함된다")
    func permissionDeniedMentionsFullDiskAccess() {
        let error = KTalkError.permissionDenied
        #expect(error.errorDescription?.contains("Full Disk Access") == true)
    }

    @Test("invalidISODate 메시지에 ISO 8601 형식 예시가 포함된다")
    func invalidISODateIncludesFormatExample() {
        let error = KTalkError.invalidISODate("bad-date")
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("ISO 8601") || desc.contains("ISO8601"))
        #expect(desc.contains("2025-"))
    }

    @Test("chatNotFound 메시지에 chat ID가 포함된다")
    func chatNotFoundIncludesChatId() {
        let error = KTalkError.chatNotFound(12345)
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("12345"))
    }

    @Test("invalidChatTarget 케이스가 설명을 반환한다")
    func invalidChatTargetHasDescription() {
        let error = KTalkError.invalidChatTarget("test-target")
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("appleScriptFailure 케이스가 설명을 반환한다")
    func appleScriptFailureHasDescription() {
        let error = KTalkError.appleScriptFailure("script error")
        #expect((error.errorDescription ?? "").isEmpty == false)
    }

    @Test("기존 에러 케이스도 errorDescription이 있다")
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
