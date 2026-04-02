import ArgumentParser
import Foundation
import KTalkCore

struct SchemaCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "schema",
        abstract: "DB 스키마 출력 (CREATE TABLE 문)"
    )

    @Option(name: .long, help: "데이터베이스 파일 경로")
    var db: String?

    @Option(name: .long, help: "데이터베이스 암호화 키")
    var key: String?

    func run() throws {
        let reader = try openDatabase(dbPath: db, key: key)
        defer { reader.close() }

        let tables = try reader.schema()
        if tables.isEmpty {
            print("테이블을 찾을 수 없습니다 (데이터베이스가 암호화되었을 수 있습니다).")
            return
        }

        for sql in tables {
            print("\(sql);")
            print()
        }
    }
}
