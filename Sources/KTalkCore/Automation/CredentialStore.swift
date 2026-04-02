import Foundation

/// Stores and retrieves KakaoTalk login credentials in the macOS Keychain.
public struct CredentialStore: Sendable {

    static let service = "com.ktalk.credentials"
    static let emailAccount = "kakaotalk-email"
    static let passwordAccount = "kakaotalk-password"

    public init() {}

    // MARK: - Read

    public var email: String? {
        Self.readKeychain(account: Self.emailAccount)
    }

    public var password: String? {
        Self.readKeychain(account: Self.passwordAccount)
    }

    public var hasCredentials: Bool {
        email != nil && password != nil
    }

    // MARK: - Write

    public func save(email: String, password: String) throws {
        try Self.writeKeychain(account: Self.emailAccount, value: email)
        try Self.writeKeychain(account: Self.passwordAccount, value: password)
    }

    public func clear() {
        Self.deleteKeychain(account: Self.emailAccount)
        Self.deleteKeychain(account: Self.passwordAccount)
    }

    // MARK: - Keychain Primitives (security CLI)

    private static func readKeychain(account: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", service,
            "-a", account,
            "-w",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private static func writeKeychain(account: String, value: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "add-generic-password",
            "-s", service,
            "-a", account,
            "-w", value,
            "-U",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CredentialError.keychainError(OSStatus(process.terminationStatus))
        }
    }

    private static func deleteKeychain(account: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "delete-generic-password",
            "-s", service,
            "-a", account,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

public enum CredentialError: Error, CustomStringConvertible {
    case keychainError(OSStatus)

    public var description: String {
        switch self {
        case .keychainError(let status):
            return "Keychain error: exit code \(status)"
        }
    }
}
