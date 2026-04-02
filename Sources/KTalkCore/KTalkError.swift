import Foundation

public enum KTalkError: Error {
    // Existing cases
    case appNotInstalled
    case uuidNotFound
    case plistNotFound(String)
    case plistParseError
    case userIdNotFound([String])
    case databaseNotFound(String)
    case databaseOpenFailed(String)
    case sqlError(String)
    case kakaoTalkNotInstalled

    // New cases
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
            return "KakaoTalk.app is not installed"
        case .uuidNotFound:
            return "Could not read IOPlatformUUID from ioreg"
        case .plistNotFound(let path):
            return "KakaoTalk preferences not found: \(path)"
        case .plistParseError:
            return "Failed to parse KakaoTalk preferences plist"
        case .userIdNotFound(let keys):
            return "Could not find user ID in plist. Available keys: \(keys.joined(separator: ", "))"
        case .databaseNotFound(let path):
            return "KakaoTalk database not found: \(path)"
        case .databaseOpenFailed(let msg):
            return "Failed to open database: \(msg)"
        case .sqlError(let msg):
            return "SQL error: \(msg)"
        case .permissionDenied:
            return "Cannot access chat.db. Enable Full Disk Access for Terminal in System Settings > Privacy & Security."
        case .invalidISODate(let input):
            return "Invalid date format: '\(input)'. Use ISO 8601 format (e.g. 2025-01-15T10:30:00Z)"
        case .invalidChatTarget(let target):
            return "Invalid chat target: '\(target)'. Provide a valid handle or chat ID."
        case .chatNotFound(let id):
            return "Chat ID \(id) not found."
        case .appleScriptFailure(let msg):
            return "AppleScript execution failed. Check Automation permissions: \(msg)"
        case .databaseError(let msg):
            return "Database error: \(msg)"
        }
    }
}

extension KTalkError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown error"
    }
}
