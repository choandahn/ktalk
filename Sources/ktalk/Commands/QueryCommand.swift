import ArgumentParser
import Foundation
import KTalkCore

struct QueryCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "query",
        abstract: "raw SQL 쿼리 실행 (읽기 전용)"
    )

    @Argument(help: "실행할 SQL 쿼리")
    var sql: String

    @Option(name: .long, help: "데이터베이스 파일 경로")
    var db: String?

    @Option(name: .long, help: "데이터베이스 암호화 키")
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
