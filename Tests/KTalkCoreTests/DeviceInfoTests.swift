import Foundation
import Testing
@testable import KTalkCore

@Suite("DeviceInfo")
struct DeviceInfoTests {

    @Test("platformUUID는 유효한 UUID 형식을 반환한다")
    func platformUUIDFormat() throws {
        let uuid = try DeviceInfo.platformUUID()
        // 형식: 8-4-4-4-12 대문자 16진수
        let pattern = #"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(uuid.startIndex..., in: uuid)
        #expect(regex.firstMatch(in: uuid, range: range) != nil, "UUID '\(uuid)'가 예상 형식과 다릅니다")
    }

    @Test("containerPath는 올바른 번들 ID를 포함한다")
    func containerPathContainsCorrectBundle() {
        let path = DeviceInfo.containerPath
        #expect(path.contains("com.kakao.KakaoTalkMac"))
        #expect(path.contains("Application Support"))
    }

    @Test("preferencesPath는 Preferences 디렉터리를 가리킨다")
    func preferencesPathContainsPreferences() {
        let path = DeviceInfo.preferencesPath
        #expect(path.contains("com.kakao.KakaoTalkMac"))
        #expect(path.contains("Preferences"))
    }

    @Test("discoverDatabaseFile은 nil 또는 78자 hex 파일 경로를 반환한다")
    func discoverDatabaseFileReturnsValidPathOrNil() {
        guard let path = DeviceInfo.discoverDatabaseFile() else {
            // KakaoTalk 미설치 환경에서는 nil 허용
            return
        }
        let filename = URL(fileURLWithPath: path).lastPathComponent
        #expect(filename.count == 78, "파일명은 78자여야 합니다. 실제: \(filename.count)자")
        #expect(filename.allSatisfy { $0.isHexDigit }, "파일명 '\(filename)'은 16진수로만 이루어져야 합니다")
    }

    @Test("countDatabaseFiles는 음수가 아닌 값을 반환한다")
    func countDatabaseFilesNonNegative() {
        #expect(DeviceInfo.countDatabaseFiles() >= 0)
    }

    @Test("candidateUserIds는 양수 정수 배열을 반환한다")
    func candidateUserIdsArePositive() {
        for id in DeviceInfo.candidateUserIds() {
            #expect(id > 0, "userId는 양수여야 합니다. 실제: \(id)")
        }
    }

    // MARK: - 통합 테스트 (KakaoTalk 설치 환경에서만 실행)

    @Test("userId는 양수 정수를 반환한다 (통합)")
    func userIdReturnsPositiveInt() throws {
        guard DeviceInfo.discoverDatabaseFile() != nil else { return }
        let id = try DeviceInfo.userId()
        #expect(id > 0, "userId는 양수여야 합니다. 실제: \(id)")
    }
}
