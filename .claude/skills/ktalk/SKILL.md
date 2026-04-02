---
name: ktalk
description: KakaoTalk CLI for listing chats, reading history, searching messages, streaming new messages, and sending via macOS Accessibility API.
---

# ktalk

Use `ktalk` to read and send KakaoTalk messages on macOS.

## When to Use

- User asks to read KakaoTalk messages or chat history
- Listing KakaoTalk conversations
- Searching KakaoTalk messages
- Sending KakaoTalk messages
- Streaming new KakaoTalk messages in real-time
- Querying the KakaoTalk database directly

## When NOT to Use

- iMessage/SMS → use `imsg` skill
- Slack messages → use `slack` skill
- Telegram/WhatsApp/Signal → use respective tools
- Group chat management (adding/removing members) → not supported
- Bulk/mass messaging → always confirm with user first

## Requirements

- macOS 14+ with KakaoTalk installed and signed in
- Full Disk Access for terminal
- Accessibility permission for terminal (for sending)

## Common Commands

### List Chats

```bash
ktalk chats --limit 10 --json
```

### View History

```bash
# By chat ID
ktalk history --chat-id 285808228519222 --limit 20 --json

# Filter by time
ktalk history --chat-id 285808228519222 --since 24h --json

# Filter by date range
ktalk history --chat-id 285808228519222 --start 2025-01-01T00:00:00Z --end 2025-02-01T00:00:00Z --json
```

### Search Messages

```bash
ktalk search "keyword" --limit 20 --json
```

### Watch for New Messages

```bash
ktalk watch --json
ktalk watch --chat-id 285808228519222 --json
```

### Send Messages

```bash
# Text message
ktalk send --to "John" --text "Hello!"

# Send to self-chat
ktalk send --to "Me" --text "Note to self" --self
```

### Check Status

```bash
ktalk status
```

### Raw SQL Query

```bash
ktalk query "SELECT chatId, chatName FROM NTChatRoom LIMIT 10"
```

### Database Schema

```bash
ktalk schema
```

### JSON-RPC 2.0 Server

```bash
ktalk rpc
```

Supported methods: `chats.list`, `messages.history`, `send`, `watch.subscribe`, `watch.unsubscribe`.

## Safety Rules

1. **Always confirm recipient and message content** before sending
2. **Never send to unknown contacts** without explicit user approval
3. **Rate limit yourself** — don't spam
4. **Read-only by default** — the database is never modified

## Example Workflow

User: "Send a message to John saying I'll be late"

```bash
# 1. Find John's chat
ktalk chats --json | jq '.[] | select(.displayName | contains("John"))'

# 2. Confirm with user
# "Found chat with John (ID: 12345). Send 'I'll be late'?"

# 3. Send after confirmation
ktalk send --to "John" --text "I'll be late"
```
