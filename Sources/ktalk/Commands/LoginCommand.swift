import ArgumentParser
import Foundation
import KTalkCore

struct LoginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "KakaoTalk 로그인 자격증명 관리"
    )

    @Flag(name: .long, help: "저장된 자격증명 상태 확인")
    var status = false

    @Flag(name: .long, help: "저장된 자격증명 삭제")
    var clear = false

    @Option(name: .long, help: "이메일 주소 (대화형 프롬프트 생략)")
    var email: String?

    @Option(name: .long, help: "비밀번호 (대화형 프롬프트 생략)")
    var password: String?

    func run() throws {
        let store = CredentialStore()

        if clear {
            store.clear()
            print("자격증명이 삭제되었습니다.")
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
            Swift.print("KakaoTalk 이메일: ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty else {
                Swift.print("오류: 이메일이 비어 있습니다.")
                throw ExitCode.failure
            }
            emailValue = input
        }

        if let p = password {
            passwordValue = p
        } else {
            guard let cStr = getpass("KakaoTalk 비밀번호: ") else {
                Swift.print("오류: 비밀번호를 읽을 수 없습니다.")
                throw ExitCode.failure
            }
            passwordValue = String(cString: cStr)
            guard !passwordValue.isEmpty else {
                Swift.print("오류: 비밀번호가 비어 있습니다.")
                throw ExitCode.failure
            }
        }

        try store.save(email: emailValue, password: passwordValue)
        print("자격증명이 Keychain에 저장되었습니다.")
    }

    private func printStatus(store: CredentialStore) {
        let hasCreds = store.hasCredentials
        print("로그인 상태")
        print("===========")
        print("저장된 자격증명: \(hasCreds ? "있음" : "없음")")
        if hasCreds, let e = store.email {
            print("이메일: \(maskEmail(e))")
        }
    }

    private func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return "***" }
        let local = email[email.startIndex..<atIndex]
        if local.count <= 2 { return "**@\(email[email.index(after: atIndex)...])" }
        return "\(local.prefix(2))***@\(email[email.index(after: atIndex)...])"
    }
}
