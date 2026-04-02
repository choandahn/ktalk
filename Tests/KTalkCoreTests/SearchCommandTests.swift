import Testing
import ArgumentParser
@testable import ktalk

@Suite("SearchCommand Parsing Tests")
struct SearchCommandTests {

    @Test("Parses query positional argument")
    func parsesQueryArgument() throws {
        let cmd = try SearchCommand.parse(["hello"])
        #expect(cmd.query == "hello")
    }

    @Test("Default limit is 20")
    func defaultLimitIsTwenty() throws {
        let cmd = try SearchCommand.parse(["hello"])
        #expect(cmd.limit == 20)
    }

    @Test("Parses --limit option")
    func parsesLimitOption() throws {
        let cmd = try SearchCommand.parse(["hello", "--limit", "5"])
        #expect(cmd.limit == 5)
    }

    @Test("Default json flag is false")
    func defaultJsonIsFalse() throws {
        let cmd = try SearchCommand.parse(["hello"])
        #expect(cmd.json == false)
    }

    @Test("Parses --json flag as true")
    func parsesJsonFlag() throws {
        let cmd = try SearchCommand.parse(["hello", "--json"])
        #expect(cmd.json == true)
    }

    @Test("Fails to parse without query")
    func failsWithoutQuery() {
        #expect(throws: Error.self) {
            try SearchCommand.parse([])
        }
    }
}
