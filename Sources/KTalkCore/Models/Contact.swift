import Foundation

/// A KakaoTalk contact/friend.
public struct Contact: Codable, Sendable {
    public let id: Int64
    public let name: String
    public let profileImageUrl: String?
    public let statusMessage: String?

    public init(id: Int64, name: String, profileImageUrl: String?, statusMessage: String?) {
        self.id = id
        self.name = name
        self.profileImageUrl = profileImageUrl
        self.statusMessage = statusMessage
    }
}
