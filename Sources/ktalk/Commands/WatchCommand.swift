import ArgumentParser
import Foundation
import KTalkCore

struct WatchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "watch",
        abstract: "새 메시지 실시간 감시"
    )

    @Option(name: .long, help: "감시할 채팅방 ID (생략 시 전체)")
    var chatId: Int64?

    @Option(name: .long, help: "이 logId 이후의 메시지만 수신")
    var sinceLogId: Int64?

    @Option(name: .long, help: "폴링 간격 초 (기본: 2)")
    var interval: Double = 2.0

    @Option(name: .long, help: "시작 날짜 필터 (ISO8601, 예: 2025-01-15T10:30:00Z)")
    var start: String?

    @Option(name: .long, help: "종료 날짜 필터 (ISO8601, 예: 2025-01-15T23:59:59Z)")
    var end: String?

    @Flag(name: .long, help: "NDJSON 형식으로 출력")
    var json = false

    @Option(name: .long, help: "데이터베이스 파일 경로 (자동 감지)")
    var db: String?

    @Option(name: .long, help: "데이터베이스 암호화 키 (자동 유도)")
    var key: String?

    func run() throws {
        let (path, secureKey) = try resolveDatabasePath(dbPath: db, key: key)

        let iso8601 = ISO8601DateFormatter()
        let startDate: Date? = start.flatMap { iso8601.date(from: $0) }
        let endDate: Date? = end.flatMap { iso8601.date(from: $0) }

        signal(SIGINT) { _ in
            fputs("\n감시를 중단합니다...\n", stderr)
            Darwin.exit(0)
        }

        fputs("새 메시지 감시 중 (폴링 간격: \(interval)s)...\n", stderr)

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
                    // chatId 필터
                    if let filterChatId = chatId, msg.chatId != filterChatId { continue }
                    // 날짜 필터 (timestamp 문자열을 Date로 파싱)
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

/// 데이터베이스 경로와 키를 반환합니다 (데이터베이스를 열지 않음).
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
