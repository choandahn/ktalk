import Testing
import ArgumentParser
@testable import ktalk

@Suite("LoginCommand 파싱 테스트")
struct LoginCommandTests {

    @Test("--status 플래그 파싱")
    func parsesStatusFlag() throws {
        let cmd = try LoginCommand.parse(["--status"])
        #expect(cmd.status == true)
        #expect(cmd.clear == false)
    }

    @Test("--clear 플래그 파싱")
    func parsesClearFlag() throws {
        let cmd = try LoginCommand.parse(["--clear"])
        #expect(cmd.clear == true)
        #expect(cmd.status == false)
    }

    @Test("--email, --password 옵션 파싱")
    func parsesEmailAndPassword() throws {
        let cmd = try LoginCommand.parse(["--email", "user@example.com", "--password", "secret"])
        #expect(cmd.email == "user@example.com")
        #expect(cmd.password == "secret")
    }

    @Test("인자 없이 파싱 — 기본값 확인")
    func parsesDefaults() throws {
        let cmd = try LoginCommand.parse([])
        #expect(cmd.status == false)
        #expect(cmd.clear == false)
        #expect(cmd.email == nil)
        #expect(cmd.password == nil)
    }
}

@Suite("QueryCommand 파싱 테스트")
struct QueryCommandTests {

    @Test("SQL 인자 파싱")
    func parsesSQLArgument() throws {
        let cmd = try QueryCommand.parse(["SELECT * FROM NTChatRoom LIMIT 5"])
        #expect(cmd.sql == "SELECT * FROM NTChatRoom LIMIT 5")
    }

    @Test("SQL 인자 없이 파싱하면 실패한다")
    func failsWithoutSQL() {
        #expect(throws: Error.self) {
            try QueryCommand.parse([])
        }
    }
}

@Suite("SchemaCommand 존재 테스트")
struct SchemaCommandTests {

    @Test("SchemaCommand 인스턴스 생성 가능")
    func canBeCreated() throws {
        let cmd = try SchemaCommand.parse([])
        _ = cmd
    }
}
