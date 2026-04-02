import Testing
@testable import KTalkCore

@Suite("Automation Tests")
struct AutomationTests {

    // MARK: - AppState

    @Test("AppState has notRunning case")
    func appStateNotRunning() {
        let state = AppState.notRunning
        #expect(state.rawValue == "notRunning")
    }

    @Test("AppState has launching case")
    func appStateLaunching() {
        let state = AppState.launching
        #expect(state.rawValue == "launching")
    }

    @Test("AppState has loginScreen case")
    func appStateLoginScreen() {
        let state = AppState.loginScreen
        #expect(state.rawValue == "loginScreen")
    }

    @Test("AppState has loggedIn case")
    func appStateLoggedIn() {
        let state = AppState.loggedIn
        #expect(state.rawValue == "loggedIn")
    }

    @Test("AppState has updateRequired case")
    func appStateUpdateRequired() {
        let state = AppState.updateRequired
        #expect(state.rawValue == "updateRequired")
    }

    @Test("AppState has unknown case")
    func appStateUnknown() {
        let state = AppState.unknown
        #expect(state.rawValue == "unknown")
    }

    // MARK: - KakaoAutomator

    @Test("KakaoAutomator bundleId is com.kakao.KakaoTalkMac")
    func kakaoAutomatorBundleId() {
        #expect(KakaoAutomator.bundleId == "com.kakao.KakaoTalkMac")
    }

    // MARK: - AutomationError

    @Test("AutomationError noWindows has description")
    func automationErrorNoWindows() {
        let error = AutomationError.noWindows
        #expect(!error.description.isEmpty)
    }

    @Test("AutomationError chatNotFound includes chat name")
    func automationErrorChatNotFound() {
        let error = AutomationError.chatNotFound("테스트채팅")
        #expect(error.description.contains("테스트채팅"))
    }

    @Test("AutomationError inputFieldNotFound has description")
    func automationErrorInputFieldNotFound() {
        let error = AutomationError.inputFieldNotFound
        #expect(!error.description.isEmpty)
    }

    @Test("AutomationError sendFailed includes message")
    func automationErrorSendFailed() {
        let error = AutomationError.sendFailed("연결 실패")
        #expect(error.description.contains("연결 실패"))
    }
}
