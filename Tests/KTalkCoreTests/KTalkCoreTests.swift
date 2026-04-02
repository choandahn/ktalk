import Testing
@testable import KTalkCore

@Suite("KTalkCore")
struct KTalkCoreTests {
    @Test("Version is defined")
    func versionIsDefined() {
        #expect(!KTalkCore.version.isEmpty)
    }
}
