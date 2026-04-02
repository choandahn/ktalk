import ArgumentParser
import Foundation
import KTalkCore

struct HistoryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "history",
        abstract: "특정 채팅방의 메시지 이력 조회"
    )

    @Option(name: .long, help: "채팅방 ID (필수)")
    var chatId: Int64

    @Option(name: .long, help: "최대 조회 수 (기본: 50)")
    var limit: Int = 50

    @Option(name: .long, help: "이 기간 이후의 메시지만 (예: 1h, 24h, 7d)")
    var since: String?

    @Option(name: .long, help: "시작 날짜 필터 (ISO8601, 예: 2025-01-15T10:30:00Z)")
    var start: String?

    @Option(name: .long, help: "종료 날짜 필터 (ISO8601, 예: 2025-01-15T23:59:59Z)")
    var end: String?

    @Flag(name: .long, help: "JSON 형식으로 출력")
    var json = false

    @Option(name: .long, help: "데이터베이스 파일 경로 (자동 감지)")
    var db: String?

    @Option(name: .long, help: "데이터베이스 암호화 키 (자동 유도)")
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
                print("메시지가 없습니다.")
                return
            }
            for msg in messages.reversed() {
                print(OutputFormatter.formatMessage(msg))
            }
        }
    }
}
