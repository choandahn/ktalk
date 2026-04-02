import ArgumentParser
import Foundation
import KTalkCore

struct SearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "메시지 검색"
    )

    @Argument(help: "검색어")
    var query: String

    @Option(name: .long, help: "최대 결과 수 (기본: 20)")
    var limit: Int = 20

    @Flag(name: .long, help: "JSON Lines 형식으로 출력")
    var json = false

    @Option(name: .long, help: "데이터베이스 파일 경로 (자동 감지)")
    var db: String?

    @Option(name: .long, help: "데이터베이스 암호화 키 (자동 유도)")
    var key: String?

    func run() throws {
        let reader = try openDatabase(dbPath: db, key: key)
        defer { reader.close() }

        let results = try reader.search(query: query, limit: limit)

        if json {
            for msg in results {
                var dict: [String: Any] = [
                    "id": msg.id,
                    "chat_id": msg.chatId,
                    "sender_id": msg.senderId,
                    "type": String(describing: msg.type),
                    "timestamp": ISO8601DateFormatter().string(from: msg.createdAt),
                    "is_from_me": msg.isFromMe,
                ]
                if let name = msg.senderName { dict["sender"] = name }
                if let text = msg.text { dict["text"] = text }
                if let data = try? JSONSerialization.data(withJSONObject: dict),
                   let line = String(data: data, encoding: .utf8) {
                    print(line)
                }
            }
        } else {
            if results.isEmpty {
                print("'\(query)'에 해당하는 메시지가 없습니다.")
                return
            }
            print("총 \(results.count)개 메시지:")
            print()
            for msg in results {
                let sender = msg.isFromMe ? "나" : (msg.senderName ?? "알 수 없음")
                let time = formatDate(msg.createdAt)
                let text = msg.text ?? ""
                print("[\(time)] \(sender) (\(msg.chatId)): \(text)")
            }
        }
    }
}
