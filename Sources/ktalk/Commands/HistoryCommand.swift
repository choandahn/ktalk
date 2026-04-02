import ArgumentParser
import Foundation
import KTalkCore

struct HistoryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "Show message history for a chat room"
    )

    @Option(name: .long, help: "Chat room ID (required)")
    var chatId: Int64

    @Option(name: .long, help: "Maximum results (default: 50)")
    var limit: Int = 50

    @Option(name: .long, help: "Only messages after this duration (e.g. 1h, 24h, 7d)")
    var since: String?

    @Option(name: .long, help: "Start date filter (ISO8601, e.g. 2025-01-15T10:30:00Z)")
    var start: String?

    @Option(name: .long, help: "End date filter (ISO8601, e.g. 2025-01-15T23:59:59Z)")
    var end: String?

    @Flag(name: .long, help: "Output as JSON")
    var json = false

    @Option(name: .long, help: "Database file path (auto-detected)")
    var db: String?

    @Option(name: .long, help: "Database encryption key (auto-derived)")
    var key: String?

    func run() throws {
        let reader = try openDatabase(dbPath: db, key: key)
        defer { reader.close() }

        let sinceDate = since.flatMap { str -> Date? in
            guard let interval = DurationParser.parse(str) else { return nil }
            return Date().addingTimeInterval(-interval)
        }

        let iso8601 = ISO8601DateFormatter()

        let startDate: Date?
        if let s = start {
            guard let d = iso8601.date(from: s) else {
                throw KTalkError.invalidISODate(s)
            }
            startDate = d
        } else {
            startDate = nil
        }

        let endDate: Date?
        if let e = end {
            guard let d = iso8601.date(from: e) else {
                throw KTalkError.invalidISODate(e)
            }
            endDate = d
        } else {
            endDate = nil
        }

        let messages = try reader.messages(chatId: chatId, since: sinceDate, start: startDate, end: endDate, limit: limit)

        if json {
            JSONOutput.printJSONArray(messages)
        } else {
            if messages.isEmpty {
                print("No messages found.")
                return
            }
            for msg in messages.reversed() {
                print(OutputFormatter.formatMessage(msg))
            }
        }
    }
}
