import ArgumentParser
import Foundation
import KTalkCore

struct ChatsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chats",
        abstract: "List chat rooms"
    )

    @Option(name: .long, help: "Maximum results (default: 20)")
    var limit: Int = 20

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    @Option(name: .long, help: "Database file path (auto-detected)")
    var db: String?

    @Option(name: .long, help: "Database encryption key (auto-derived)")
    var key: String?

    func run() throws {
        let reader = try openDatabase(dbPath: db, key: key)
        defer { reader.close() }

        let chats = try reader.chats(limit: limit)

        if json {
            JSONOutput.printJSONArray(chats)
        } else {
            if chats.isEmpty {
                print("No chats found.")
                return
            }
            for chat in chats {
                print(OutputFormatter.formatChat(chat))
            }
        }
    }
}
