import ArgumentParser
import Foundation
import KTalkCore

struct WatchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "watch",
        abstract: "Stream new messages in real-time"
    )

    @Option(name: .long, help: "Chat room ID to watch (omit for all)")
    var chatId: Int64?

    @Option(name: .long, help: "Only receive messages after this logId")
    var sinceLogId: Int64?

    @Option(name: .long, help: "Polling interval in seconds (default: 2)")
    var interval: Double = 2.0

    @Option(name: .long, help: "Start date filter (ISO8601, e.g. 2025-01-15T10:30:00Z)")
    var start: String?

    @Option(name: .long, help: "End date filter (ISO8601, e.g. 2025-01-15T23:59:59Z)")
    var end: String?

    @Flag(name: .long, help: "Output as NDJSON")
    var json = false

    @Option(name: .long, help: "Database file path (auto-detected)")
    var db: String?

    @Option(name: .long, help: "Database encryption key (auto-derived)")
    var key: String?

    func run() throws {
        let (path, secureKey) = try resolveDatabasePath(dbPath: db, key: key)

        let iso8601 = ISO8601DateFormatter()
        let startDate: Date? = start.flatMap { iso8601.date(from: $0) }
        let endDate: Date? = end.flatMap { iso8601.date(from: $0) }

        signal(SIGINT) { _ in
            fputs("\nStopping watch...\n", stderr)
            Darwin.exit(0)
        }

        fputs("Watching for new messages (poll interval: \(interval)s)...\n", stderr)

        let watcher = DatabaseWatcher(
            databasePath: path,
            key: secureKey,
            pollInterval: interval,
            startFromLogId: sinceLogId
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        watcher.watch(
            onMessages: { messages in
                for msg in messages {
                    // chatId filter
                    if let filterChatId = chatId, msg.chatId != filterChatId { continue }
                    // date filter (parse timestamp string to Date)
                    if startDate != nil || endDate != nil {
                        let msgDate = iso8601.date(from: msg.timestamp) ?? .distantPast
                        if let startDate, msgDate < startDate { continue }
                        if let endDate, msgDate > endDate { continue }
                    }

                    if json {
                        if let data = try? encoder.encode(msg),
                           let line = String(data: data, encoding: .utf8) {
                            print(line)
                            fflush(stdout)
                        }
                    } else {
                        print(OutputFormatter.formatSyncMessage(msg))
                        fflush(stdout)
                    }
                }
            },
            onError: { error in
                fputs("Error: \(error)\n", stderr)
            }
        )
    }
}

/// Returns the database path and key (does not open the database).
func resolveDatabasePath(dbPath: String?, key: String?) throws -> (path: String, key: String?) {
    if let dbPath {
        return (dbPath, key)
    }

    let uuid = try DeviceInfo.platformUUID()

    if let uid = try? DeviceInfo.userId() {
        let dbName = KeyDerivation.databaseName(userId: uid, uuid: uuid)
        let candidates = [
            "\(DeviceInfo.containerPath)/\(dbName)",
            "\(DeviceInfo.containerPath)/\(dbName).db",
        ]
        if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            let secureKey = key ?? KeyDerivation.secureKey(userId: uid, uuid: uuid)
            return (found, secureKey)
        }
    }

    guard let discoveredPath = DeviceInfo.discoverDatabaseFile() else {
        let uid = try DeviceInfo.userId()
        let dbName = KeyDerivation.databaseName(userId: uid, uuid: uuid)
        throw KTalkError.databaseNotFound("\(DeviceInfo.containerPath)/\(dbName)")
    }

    if let key {
        return (discoveredPath, key)
    }

    var candidateIds = (try? DeviceInfo.userId()).map { [$0] } ?? [Int]()
    candidateIds += DeviceInfo.candidateUserIds().filter { !candidateIds.contains($0) }

    for uid in candidateIds {
        let candidateKey = KeyDerivation.secureKey(userId: uid, uuid: uuid)
        let reader = DatabaseReader(databasePath: discoveredPath)
        if (try? reader.open(key: candidateKey)) != nil {
            reader.close()
            return (discoveredPath, candidateKey)
        }
    }

    return (discoveredPath, nil)
}
