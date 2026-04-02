import ArgumentParser
import Foundation
import KTalkCore

struct SchemaCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "Print DB schema (CREATE TABLE statements)"
    )

    @Option(name: .long, help: "Database file path")
    var db: String?

    @Option(name: .long, help: "Database encryption key")
    var key: String?

    func run() throws {
        let reader = try openDatabase(dbPath: db, key: key)
        defer { reader.close() }

        let tables = try reader.schema()
        if tables.isEmpty {
            print("No tables found (database may be encrypted).")
            return
        }

        for sql in tables {
            print("\(sql);")
            print()
        }
    }
}
