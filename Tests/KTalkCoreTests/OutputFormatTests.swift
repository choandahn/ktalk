import Foundation
import Testing
@testable import KTalkCore

@Suite("Output Format Tests")
struct OutputFormatTests {

    private func makeMessage(
        sender: String? = "홍길동",
        text: String? = "안녕!",
        isFromMe: Bool = false,
        timestamp: TimeInterval = 1_736_937_000
    ) -> Message {
        Message(
            id: 1,
            chatId: 1,
            senderId: 999,
            senderName: sender,
            text: text,
            type: .text,
            createdAt: Date(timeIntervalSince1970: timestamp),
            isFromMe: isFromMe
        )
    }

    @Test("formatMessage는 대괄호로 시작한다")
    func formatMessageStartsWithBracket() {
        let msg = makeMessage()
        let result = OutputFormatter.formatMessage(msg)
        #expect(result.hasPrefix("["))
    }

    @Test("formatMessage는 ] sender: text 형식을 포함한다")
    func formatMessageContainsSenderAndText() {
        let msg = makeMessage(sender: "홍길동", text: "안녕!")
        let result = OutputFormatter.formatMessage(msg)
        #expect(result.contains("] 홍길동: 안녕!"))
    }

    @Test("formatMessage — isFromMe이면 Me로 표시")
    func formatMessageFromMe() {
        let msg = makeMessage(sender: nil, text: "Hello", isFromMe: true)
        let result = OutputFormatter.formatMessage(msg)
        #expect(result.contains("] Me: Hello"))
    }

    @Test("formatMessage — senderName nil이면 Unknown으로 표시")
    func formatMessageUnknownSender() {
        let msg = makeMessage(sender: nil, text: "Hi", isFromMe: false)
        let result = OutputFormatter.formatMessage(msg)
        #expect(result.contains("] Unknown: Hi"))
    }

    @Test("formatMessage — text nil이면 타입을 표시")
    func formatMessageNilText() {
        let msg = Message(
            id: 1, chatId: 1, senderId: 1, senderName: "A",
            text: nil, type: .photo, createdAt: Date(), isFromMe: false
        )
        let result = OutputFormatter.formatMessage(msg)
        #expect(result.contains("[photo]"))
    }

    @Test("formatMessage 날짜 블록은 19자이다 (YYYY-MM-DD HH:mm:ss)")
    func formatMessageDateBlockLength() {
        let msg = makeMessage()
        let result = OutputFormatter.formatMessage(msg)
        guard let closeIdx = result.firstIndex(of: "]") else {
            Issue.record("] 미발견")
            return
        }
        let dateBlock = String(result[result.index(after: result.startIndex)..<closeIdx])
        #expect(dateBlock.count == 19)
    }

    @Test("formatChat은 ID와 이름을 포함한다")
    func formatChatContainsIdAndName() {
        let chat = Chat(
            id: 42,
            type: .group,
            displayName: "테스트 채팅방",
            memberCount: 5,
            lastMessageId: nil,
            lastMessageAt: nil,
            unreadCount: 0
        )
        let result = OutputFormatter.formatChat(chat)
        #expect(result.contains("42"))
        #expect(result.contains("테스트 채팅방"))
    }

    @Test("formatChat은 멤버 수를 포함한다")
    func formatChatContainsMemberCount() {
        let chat = Chat(
            id: 1,
            type: .group,
            displayName: "그룹",
            memberCount: 10,
            lastMessageId: nil,
            lastMessageAt: nil,
            unreadCount: 0
        )
        let result = OutputFormatter.formatChat(chat)
        #expect(result.contains("10"))
    }
}
