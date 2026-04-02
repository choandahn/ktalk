import Testing
import ArgumentParser
@testable import ktalk

@Suite("SearchCommand 파싱 테스트")
struct SearchCommandTests {

    @Test("query 위치 인자로 파싱된다")
    func parsesQueryArgument() throws {
        let cmd = try SearchCommand.parse(["hello"])
        #expect(cmd.query == "hello")
    }

    @Test("기본 limit은 20이다")
    func defaultLimitIsTwenty() throws {
        let cmd = try SearchCommand.parse(["hello"])
        #expect(cmd.limit == 20)
    }

    @Test("--limit 옵션으로 limit을 변경할 수 있다")
    func parsesLimitOption() throws {
        let cmd = try SearchCommand.parse(["hello", "--limit", "5"])
        #expect(cmd.limit == 5)
    }

    @Test("기본 json 플래그는 false이다")
    func defaultJsonIsFalse() throws {
        let cmd = try SearchCommand.parse(["hello"])
        #expect(cmd.json == false)
    }

    @Test("--json 플래그를 지정하면 true가 된다")
    func parsesJsonFlag() throws {
        let cmd = try SearchCommand.parse(["hello", "--json"])
        #expect(cmd.json == true)
    }

    @Test("query 없이 파싱하면 실패한다")
    func failsWithoutQuery() {
        #expect(throws: Error.self) {
            try SearchCommand.parse([])
        }
    }
}
