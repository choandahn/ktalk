import Testing
import ArgumentParser
@testable import ktalk

@Suite("LoginCommand Parsing Tests")
struct LoginCommandTests {

    @Test("Parses --status flag")
    func parsesStatusFlag() throws {
        let cmd = try LoginCommand.parse(["--status"])
        #expect(cmd.status == true)
        #expect(cmd.clear == false)
    }

    @Test("Parses --clear flag")
    func parsesClearFlag() throws {
        let cmd = try LoginCommand.parse(["--clear"])
        #expect(cmd.clear == true)
        #expect(cmd.status == false)
    }

    @Test("Parses --email and --password options")
    func parsesEmailAndPassword() throws {
        let cmd = try LoginCommand.parse(["--email", "user@example.com", "--password", "secret"])
        #expect(cmd.email == "user@example.com")
        #expect(cmd.password == "secret")
    }

    @Test("Parses with no args — verifies defaults")
    func parsesDefaults() throws {
        let cmd = try LoginCommand.parse([])
        #expect(cmd.status == false)
        #expect(cmd.clear == false)
        #expect(cmd.email == nil)
        #expect(cmd.password == nil)
    }
}

@Suite("QueryCommand Parsing Tests")
struct QueryCommandTests {

    @Test("Parses SQL argument")
    func parsesSQLArgument() throws {
        let cmd = try QueryCommand.parse(["SELECT * FROM NTChatRoom LIMIT 5"])
        #expect(cmd.sql == "SELECT * FROM NTChatRoom LIMIT 5")
    }

    @Test("Fails to parse without SQL argument")
    func failsWithoutSQL() {
        #expect(throws: Error.self) {
            try QueryCommand.parse([])
        }
    }
}

@Suite("SchemaCommand Existence Tests")
struct SchemaCommandTests {

    @Test("Can create SchemaCommand instance")
    func canBeCreated() throws {
        let cmd = try SchemaCommand.parse([])
        _ = cmd
    }
}
