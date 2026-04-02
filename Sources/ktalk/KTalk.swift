import ArgumentParser
import KTalkCore

@main
struct KTalk: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ktalk",
        abstract: "KakaoTalk CLI — read chats, send messages, stream in real-time",
        version: "0.1.0",
        subcommands: [
            StatusCommand.self,
            ChatsCommand.self,
            HistoryCommand.self,
            WatchCommand.self,
            SendCommand.self,
            SearchCommand.self,
            RPCCommand.self,
            LoginCommand.self,
            QueryCommand.self,
            SchemaCommand.self,
        ]
    )
}
