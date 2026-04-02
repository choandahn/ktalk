import Foundation

public enum KTalkError: Error {
    // 기존 케이스
    case appNotInstalled
    case uuidNotFound
    case plistNotFound(String)
    case plistParseError
    case userIdNotFound([String])
    case databaseNotFound(String)
    case databaseOpenFailed(String)
    case sqlError(String)
    case kakaoTalkNotInstalled

    // 새 케이스
    case permissionDenied
    case invalidISODate(String)
    case invalidChatTarget(String)
    case chatNotFound(Int64)
    case appleScriptFailure(String)
    case databaseError(String)
}

extension KTalkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .appNotInstalled, .kakaoTalkNotInstalled:
            return "KakaoTalk.app이 설치되어 있지 않습니다"
        case .uuidNotFound:
            return "ioreg에서 IOPlatformUUID를 읽을 수 없습니다"
        case .plistNotFound(let path):
            return "KakaoTalk preferences를 찾을 수 없습니다: \(path)"
        case .plistParseError:
            return "KakaoTalk preferences plist 파싱에 실패했습니다"
        case .userIdNotFound(let keys):
            return "plist에서 사용자 ID를 찾을 수 없습니다. 사용 가능한 키: \(keys.joined(separator: ", "))"
        case .databaseNotFound(let path):
            return "KakaoTalk 데이터베이스를 찾을 수 없습니다: \(path)"
        case .databaseOpenFailed(let msg):
            return "데이터베이스 열기 실패: \(msg)"
        case .sqlError(let msg):
            return "SQL 오류: \(msg)"
        case .permissionDenied:
            return "chat.db에 접근할 수 없습니다. 시스템 설정 > 개인정보 보호 > Full Disk Access에서 터미널을 허용해 주세요."
        case .invalidISODate(let input):
            return "잘못된 날짜 형식입니다: '\(input)'. ISO 8601 형식을 사용하세요 (예: 2025-01-15T10:30:00Z)"
        case .invalidChatTarget(let target):
            return "유효하지 않은 대화 대상입니다: '\(target)'. 올바른 핸들 또는 chat ID를 입력하세요."
        case .chatNotFound(let id):
            return "chat ID \(id)를 찾을 수 없습니다."
        case .appleScriptFailure(let msg):
            return "AppleScript 실행에 실패했습니다. Automation 권한을 확인해 주세요: \(msg)"
        case .databaseError(let msg):
            return "데이터베이스 오류: \(msg)"
        }
    }
}

extension KTalkError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "알 수 없는 오류"
    }
}
