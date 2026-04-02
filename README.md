# 💬 ktalk — KakaoTalk CLI for macOS

A macOS CLI to read, search, stream, and send KakaoTalk messages. Read-only database access via SQLCipher; sending uses macOS Accessibility API (no private APIs).

## Features
- List chats, view history, search messages, or stream new messages in real-time.
- Send text messages via macOS Accessibility API (no private APIs).
- Full-text search across all conversations.
- JSON output for programmatic integration and AI agent tooling.
- JSON-RPC 2.0 server for stdin/stdout integration.
- Encrypted database auto-decryption (SQLCipher + PBKDF2 key derivation).
- Read-only DB access — never modifies KakaoTalk data.

## Requirements
- macOS 14+ with KakaoTalk installed and signed in.
- Full Disk Access for your terminal to read the KakaoTalk database.
- Accessibility permission for your terminal to control KakaoTalk (for sending).

## Install

### Homebrew (recommended)
```bash
brew tap choandahn/ktalk
brew install ktalk
```

### Build from source
```bash
brew install sqlcipher
git clone https://github.com/choandahn/ktalk.git
cd ktalk
make build
sudo make install
# binary at ./bin/ktalk
```

## Commands
- `ktalk status` — check KakaoTalk installation, database access, and app state.
- `ktalk chats [--limit 20] [--json]` — list recent conversations.
- `ktalk history --chat-id <id> [--limit 50] [--since 24h] [--start 2025-01-01T00:00:00Z] [--end 2025-02-01T00:00:00Z] [--json]`
- `ktalk search <query> [--limit 20] [--json]` — full-text message search.
- `ktalk watch [--chat-id <id>] [--since-log-id <n>] [--interval 2] [--json]` — stream new messages.
- `ktalk send --to <name> --text "message" [--self]` — send a message.
- `ktalk rpc` — start JSON-RPC 2.0 server (stdin/stdout).
- `ktalk login [--status] [--clear]` — manage stored credentials.
- `ktalk query "<SQL>"` — execute raw SQL against the database.
- `ktalk schema` — dump database schema.

### Quick samples
```bash
# system status
ktalk status

# list 5 chats
ktalk chats --limit 5

# list chats as JSON
ktalk chats --json

# last 10 messages in a chat
ktalk history --chat-id 285808228519222 --limit 10

# filter by date and emit JSON
ktalk history --chat-id 285808228519222 --since 7d --json

# search messages
ktalk search "hello" --limit 5

# live stream all new messages as JSON
ktalk watch --json

# send a message
ktalk send --to "John" --text "Hello there"

# raw SQL query
ktalk query "SELECT chatId, chatName FROM NTChatRoom LIMIT 5"
```

## JSON output
`ktalk chats --json` emits a JSON array with fields: `id`, `type`, `displayName`, `memberCount`, `lastMessageId`, `lastMessageAt`, `unreadCount`.

`ktalk history --json` and `ktalk search --json` emit JSON with fields: `id`, `chatId`, `senderId`, `senderName`, `text`, `type`, `createdAt`, `isFromMe`.

`ktalk watch --json` emits one JSON object per line (NDJSON) as new messages arrive.

## Permissions troubleshooting
If you see "database open failed" or empty output:
1. Grant **Full Disk Access**: System Settings → Privacy & Security → Full Disk Access → add your terminal.
2. Ensure KakaoTalk is installed and signed in.
3. For sending, grant **Accessibility**: System Settings → Privacy & Security → Accessibility → add your terminal.

## Testing
```bash
make test
```

## Claude Code skill
ktalk includes a [Claude Code skill](https://code.claude.com/docs/en/skills) at `.claude/skills/ktalk/SKILL.md`. When installed, Claude Code can automatically use ktalk when you ask about KakaoTalk messages.

## Core library
The reusable Swift core lives in `Sources/KTalkCore` and is consumed by the CLI target. Apps can depend on the `KTalkCore` library target directly.

## License
MIT
