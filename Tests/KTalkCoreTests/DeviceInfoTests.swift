import Foundation
import Testing
@testable import KTalkCore

@Suite("DeviceInfo")
struct DeviceInfoTests {

    @Test("platformUUID returns valid UUID format")
    func platformUUIDFormat() throws {
        let uuid = try DeviceInfo.platformUUID()
        // Format: 8-4-4-4-12 uppercase hex digits
        let pattern = #"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(uuid.startIndex..., in: uuid)
        #expect(regex.firstMatch(in: uuid, range: range) != nil, "UUID '\(uuid)' does not match expected format")
    }

    @Test("containerPath contains correct bundle ID")
    func containerPathContainsCorrectBundle() {
        let path = DeviceInfo.containerPath
        #expect(path.contains("com.kakao.KakaoTalkMac"))
        #expect(path.contains("Application Support"))
    }

    @Test("preferencesPath points to Preferences directory")
    func preferencesPathContainsPreferences() {
        let path = DeviceInfo.preferencesPath
        #expect(path.contains("com.kakao.KakaoTalkMac"))
        #expect(path.contains("Preferences"))
    }

    @Test("discoverDatabaseFile returns nil or 78-char hex file path")
    func discoverDatabaseFileReturnsValidPathOrNil() {
        guard let path = DeviceInfo.discoverDatabaseFile() else {
            // nil is allowed when KakaoTalk is not installed
            return
        }
        let filename = URL(fileURLWithPath: path).lastPathComponent
        #expect(filename.count == 78, "Filename must be 78 chars, actual: \(filename.count)")
        #expect(filename.allSatisfy { $0.isHexDigit }, "Filename '\(filename)' must consist of hex digits only")
    }

    @Test("countDatabaseFiles returns non-negative value")
    func countDatabaseFilesNonNegative() {
        #expect(DeviceInfo.countDatabaseFiles() >= 0)
    }

    @Test("candidateUserIds returns array of positive integers")
    func candidateUserIdsArePositive() {
        for id in DeviceInfo.candidateUserIds() {
            #expect(id > 0, "userId must be positive, actual: \(id)")
        }
    }

    // MARK: - Integration Tests (run only when KakaoTalk is installed)

    @Test("userId returns positive integer (integration)")
    func userIdReturnsPositiveInt() throws {
        guard DeviceInfo.discoverDatabaseFile() != nil else { return }
        let id = try DeviceInfo.userId()
        #expect(id > 0, "userId must be positive, actual: \(id)")
    }
}
