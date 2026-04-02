import ArgumentParser
import Foundation
import KTalkCore

struct RPCCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rpc",
        abstract: "JSON-RPC 2.0 server (stdin/stdout, JSON Lines)"
    )

    @Option(name: .long, help: "Database file path (auto-detected)")
    var db: String?

    func run() throws {
        let handler = RPCHandler(databasePath: db) { data in
            if let line = String(data: data, encoding: .utf8) {
                print(line)
                fflush(stdout)
            }
        }

        signal(SIGINT) { _ in Darwin.exit(0) }

        while let line = readLine() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }
            let response = handler.handleRequest(data)
            if let responseStr = String(data: response, encoding: .utf8) {
                print(responseStr)
                fflush(stdout)
            }
        }
    }
}
