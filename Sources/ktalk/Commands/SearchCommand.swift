import ArgumentParser
import Foundation
import KTalkCore

struct SearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search messages"
    )

    @Argument(help: "Search query")
    var query: String

    @Option(name: .long, help: "Maximum results (default: 20)")
    var limit: Int = 20

    @Flag(name: .long, help: "Output as JSON Lines")
    var json = false

    @Option(name: .long, help: "Database file path (auto-detected)")
    var db: String?

    @Option(name: .long, help: "Database encryption key (auto-derived)")
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
                print("No messages found for '\(query)'.")
                return
            }
            print("\(results.count) message(s):")
            print()
            for msg in results {
                let sender = msg.isFromMe ? "me" : (msg.senderName ?? "unknown")
                let time = formatDate(msg.createdAt)
                let text = msg.text ?? ""
                print("[\(time)] \(sender) (\(msg.chatId)): \(text)")
            }
        }
    }
}
