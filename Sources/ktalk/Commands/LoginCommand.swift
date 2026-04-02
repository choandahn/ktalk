import ArgumentParser
import Foundation
import KTalkCore

struct LoginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Manage KakaoTalk login credentials"
    )

    @Flag(name: .long, help: "Check stored credential status")
    var status = false

    @Flag(name: .long, help: "Delete stored credentials")
    var clear = false

    @Option(name: .long, help: "Email address (skip interactive prompt)")
    var email: String?

    @Option(name: .long, help: "Password (skip interactive prompt)")
    var password: String?

    func run() throws {
        let store = CredentialStore()

        if clear {
            store.clear()
            print("Credentials cleared.")
            return
        }

        if status {
            printStatus(store: store)
            return
        }

        let emailValue: String
        let passwordValue: String

        if let e = email {
            emailValue = e
        } else {
            Swift.print("KakaoTalk email: ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
                Swift.print("Error: email is empty.")
                throw ExitCode.failure
            }
            emailValue = input
        }

        if let p = password {
            passwordValue = p
        } else {
            guard let cStr = getpass("KakaoTalk password: ") else {
                Swift.print("Error: could not read password.")
                throw ExitCode.failure
            }
            passwordValue = String(cString: cStr)
            guard !passwordValue.isEmpty else {
                Swift.print("Error: password is empty.")
                throw ExitCode.failure
            }
        }

        try store.save(email: emailValue, password: passwordValue)
        print("Credentials saved to Keychain.")
    }

    private func printStatus(store: CredentialStore) {
        let hasCreds = store.hasCredentials
        print("Login Status")
        print("============")
        print("Stored credentials: \(hasCreds ? "Yes" : "No")")
        if hasCreds, let e = store.email {
            print("Email: \(maskEmail(e))")
        }
    }

    private func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return "***" }
        let local = email[email.startIndex..<atIndex]
        if local.count <= 2 { return "**@\(email[email.index(after: atIndex)...])" }
        return "\(local.prefix(2))***@\(email[email.index(after: atIndex)...])"
    }
}
