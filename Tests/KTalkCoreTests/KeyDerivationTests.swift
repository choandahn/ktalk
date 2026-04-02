import Foundation
import Testing
@testable import KTalkCore

@Suite("KeyDerivation Tests")
struct KeyDerivationTests {
    let testUUID = "550e8400-e29b-41d4-a716-446655440000"
    let testUserId = 12345

    @Test("pbkdf2 produces 128-byte output")
    func pbkdf2Length() {
        let password = Data("password".utf8)
        let salt = Data("salt".utf8)
        let result = KeyDerivation.pbkdf2(password: password, salt: salt)
        #expect(result.count == 128)
    }

    @Test("hashedDeviceUUID produces 72-char base64 string")
    func hashedDeviceUUID() {
        let result = KeyDerivation.hashedDeviceUUID(testUUID)
        #expect(!result.isEmpty)
        // SHA1(20 bytes) + SHA256(32 bytes) = 52 bytes -> base64 = 72 chars
        #expect(result.count == 72)
    }

    @Test("databaseName produces 78-character hex string")
    func databaseNameLength() {
        let result = KeyDerivation.databaseName(userId: testUserId, uuid: testUUID)
        #expect(result.count == 78)
        #expect(result.allSatisfy { $0.isHexDigit })
    }

    @Test("secureKey produces non-empty hex string")
    func secureKeyNonEmpty() {
        let result = KeyDerivation.secureKey(userId: testUserId, uuid: testUUID)
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { $0.isHexDigit })
    }

    @Test("Deterministic: same inputs produce same outputs")
    func deterministic() {
        let name1 = KeyDerivation.databaseName(userId: testUserId, uuid: testUUID)
        let name2 = KeyDerivation.databaseName(userId: testUserId, uuid: testUUID)
        #expect(name1 == name2)

        let key1 = KeyDerivation.secureKey(userId: testUserId, uuid: testUUID)
        let key2 = KeyDerivation.secureKey(userId: testUserId, uuid: testUUID)
        #expect(key1 == key2)
    }
}
