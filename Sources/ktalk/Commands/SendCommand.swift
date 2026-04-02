import ArgumentParser
import Foundation
import KTalkCore

struct SendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send a message via UI automation"
    )

    @Option(name: .long, help: "Target chat room name (partial match)")
    var to: String

    @Option(name: .long, help: "Message body to send")
    var text: String

    @Flag(name: [.customLong("self")], help: "Send to self chat")
    var selfChat = false

    func run() throws {
        let automator = KakaoAutomator()
        try automator.sendMessage(to: to, message: text, selfChat: selfChat)
        let target = selfChat ? "self chat" : to
        print("Message sent to '\(target)'.")
    }
}
