import ArgumentParser
import Foundation
import KTalkCore

struct SendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "UI 자동화를 통해 메시지 전송"
    )

    @Option(name: .long, help: "수신 채팅방 이름 (부분 일치)")
    var to: String

    @Option(name: .long, help: "전송할 메시지 본문")
    var text: String

    @Flag(name: [.customLong("self")], help: "나와의 채팅으로 전송")
    var selfChat = false

    func run() throws {
        let automator = KakaoAutomator()
        try automator.sendMessage(to: to, message: text, selfChat: selfChat)
        let target = selfChat ? "나와의 채팅" : to
        print("'\(target)'에 메시지를 전송했습니다.")
    }
}
