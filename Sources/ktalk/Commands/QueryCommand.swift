import ArgumentParser
import Foundation
import KTalkCore

struct QueryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "Execute raw SQL query (read-only)"
    )

    @Argument(help: "SQL query to execute")
    var sql: String

    @Option(name: .long, help: "Database file path")
    var db: String?

    @Option(name: .long, help: "Database encryption key")
    var key: String?

    func run() throws {
        let reader = try openDatabase(dbPath: db, key: key)
        defer { reader.close() }

        let results = try reader.rawQuery(sql)

        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        if let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
