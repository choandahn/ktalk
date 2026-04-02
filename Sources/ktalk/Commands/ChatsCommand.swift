import ArgumentParser
import Foundation
import KTalkCore

struct ChatsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chats",
        abstract: "채팅방 목록 조회"
    )

    @Option(name: .long, help: "최대 조회 수 (기본: 20)")
    var limit: Int = 20

    @Flag(name: .long, help: "JSON 형식으로 출력")
    var json = false

    @Option(name: .long, help: "데이터베이스 파일 경로 (자동 감지)")
    var db: String?

    @Option(name: .long, help: "데이터베이스 암호화 키 (자동 유도)")
    var key: String?

    func run() throws {
        let reader = try openDatabase(dbPath: db, key: key)
        defer { reader.close() }

        let chats = try reader.chats(limit: limit)

        if json {
            JSONOutput.printJSONArray(chats)
        } else {
            if chats.isEmpty {
                print("채팅방이 없습니다.")
                return
            }
            for chat in chats {
                print(OutputFormatter.formatChat(chat))
            }
        }
    }
}
