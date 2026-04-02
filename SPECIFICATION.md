# imsg — Program Specification

**Version:** 0.5.0  
**Platform:** macOS 14+  
**Language:** Swift (Swift Package Manager)

---

## 1. Overview

`imsg`는 macOS의 Messages.app 데이터베이스(`~/Library/Messages/chat.db`)에 대한 CLI 인터페이스이다. iMessage 및 SMS 메시지를 읽고, 실시간 스트리밍하고, 전송할 수 있다.

**핵심 설계 원칙:**
- 데이터베이스는 읽기 전용(`mode=ro`)으로만 접근한다.
- 메시지 전송은 AppleScript(`osascript`)를 통해 수행하며, private API를 사용하지 않는다.
- 실시간 감시는 파일시스템 이벤트 기반으로 동작한다.

---

## 2. System Requirements

| 항목 | 요구사항 |
|------|----------|
| OS | macOS 14 (Sonoma) 이상 |
| Messages.app | Apple ID로 로그인 상태 |
| Full Disk Access | 터미널에 대해 허용 (chat.db 읽기용) |
| Automation 권한 | 터미널 → Messages.app 제어 허용 (전송 기능용) |
| SMS 릴레이 | iPhone에서 "Text Message Forwarding" 활성화 (SMS용) |

---

## 3. Architecture

```
┌─────────────────────────────────────────────────┐
│                   CLI Layer                      │
│  (Sources/imsg/)                                 │
│  CommandRouter → Command Specs → StdoutWriter    │
│  RPCServer (JSON-RPC 2.0 stdin/stdout)           │
├─────────────────────────────────────────────────┤
│                Core Library                      │
│  (Sources/IMsgCore/)                             │
│  MessageStore    - SQLite 읽기 전용 쿼리          │
│  MessageSender   - AppleScript 기반 전송          │
│  MessageWatcher  - 파일시스템 이벤트 감시          │
│  Models          - 도메인 객체                    │
│  MessageFilter   - 참여자/날짜/텍스트 필터         │
├─────────────────────────────────────────────────┤
│              External Dependencies               │
│  SQLite.swift · PhoneNumberKit · Commander        │
└─────────────────────────────────────────────────┘
```

**두 개의 빌드 타겟:**
- `IMsgCore` — 재사용 가능한 Swift 라이브러리
- `imsg` — CLI 실행 바이너리 (IMsgCore에 의존)

---

## 4. Commands

### 4.1 `chats` — 대화 목록 조회

최근 대화 목록을 표시한다.

```
imsg chats [--limit <n>] [--json]
```

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `--limit` | Int | 20 | 반환할 최대 대화 수 |
| `--json` | Bool | false | JSON 형식 출력 |

**출력 필드:** `id`, `name`, `identifier`, `service`, `last_message_at`

---

### 4.2 `history` — 메시지 이력 조회

특정 대화의 메시지 이력을 조회한다.

```
imsg history --chat-id <id> [--limit <n>] [--attachments]
             [--participants <handles>] [--start <iso8601>] [--end <iso8601>]
             [--json]
```

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `--chat-id` | Int64 | **필수** | 대화 ID |
| `--limit` | Int | 50 | 반환할 최대 메시지 수 |
| `--attachments` | Bool | false | 첨부파일 메타데이터 포함 |
| `--participants` | String | nil | 쉼표 구분 핸들 목록 (E.164 전화번호 또는 이메일) |
| `--start` | ISO8601 | nil | 시작 일시 필터 |
| `--end` | ISO8601 | nil | 종료 일시 필터 |
| `--json` | Bool | false | JSON 형식 출력 |

**필터 적용 순서:** 필터는 limit 적용 전에 실행되어, 필터 조건을 만족하는 메시지 중 limit 개수만큼 반환한다.

---

### 4.3 `watch` — 실시간 메시지 스트리밍

새로운 메시지를 실시간으로 감시하고 출력한다.

```
imsg watch [--chat-id <id>] [--since-rowid <n>] [--debounce <duration>]
           [--attachments] [--reactions] [--participants <handles>]
           [--start <iso8601>] [--end <iso8601>] [--json]
```

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `--chat-id` | Int64 | nil | 특정 대화만 감시 (생략 시 전체) |
| `--since-rowid` | Int64 | nil | 이 rowid 이후의 메시지만 수신 |
| `--debounce` | Duration | 250ms | 이벤트 디바운스 간격 |
| `--attachments` | Bool | false | 첨부파일 메타데이터 포함 |
| `--reactions` | Bool | false | 리액션 이벤트 포함 |
| `--participants` | String | nil | 참여자 필터 |
| `--start` | ISO8601 | nil | 시작 일시 필터 |
| `--end` | ISO8601 | nil | 종료 일시 필터 |
| `--json` | Bool | false | JSON 형식 출력 |

**동작 방식:**
1. `chat.db`, `.db-wal`, `.db-shm` 파일에 대한 파일시스템 이벤트를 감시한다.
2. 이벤트 발생 시 debounce 간격만큼 대기한 후, 마지막으로 확인한 rowid 이후의 새 메시지를 쿼리한다.
3. URL 풍선(balloon) 메시지 중복을 제거한다.
4. `AsyncThrowingStream`을 통해 메시지를 비동기적으로 전달한다.

**디바운스 형식:** `250ms`, `1s`, `2m` (밀리초, 초, 분)

---

### 4.4 `send` — 메시지 전송

iMessage 또는 SMS로 메시지를 전송한다.

```
imsg send --to <handle> [--text <message>] [--file <path>]
          [--service imessage|sms|auto] [--region <code>]
```

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `--to` | String | **필수** | 수신자 핸들 (전화번호 또는 이메일) 또는 그룹 chat identifier |
| `--text` | String | nil | 메시지 본문 (`--text` 또는 `--file` 중 하나 이상 필수) |
| `--file` | String | nil | 첨부파일 경로 |
| `--service` | Enum | auto | 전송 서비스: `imessage`, `sms`, `auto` |
| `--region` | String | US | 전화번호 정규화 지역 코드 (ISO 3166-1 alpha-2) |

**전송 구현:**
- AppleScript(`osascript`)를 통해 Messages.app을 제어한다.
- 1:1 대화: 핸들(전화번호/이메일)로 직접 전송한다.
- 그룹 대화: chat identifier 또는 chat ID로 대상을 지정한다.
- 첨부파일은 Messages 디렉토리에 스테이징 후 전송한다.

**전화번호 정규화:**
- PhoneNumberKit을 사용하여 E.164 형식(`+14155551212`)으로 정규화한다.
- `--region` 옵션으로 지역 코드를 지정한다.

---

### 4.5 `react` — 리액션(탭백) 전송

특정 메시지에 리액션을 보낸다.

```
imsg react --chat-id <id> --message-id <rowid> --reaction <type>
```

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `--chat-id` | Int64 | **필수** | 대화 ID |
| `--message-id` | Int64 | **필수** | 대상 메시지 rowid |
| `--reaction` | String | **필수** | 리액션 타입 |

**리액션 타입:**
- 표준 탭백: `love`, `like`, `dislike`, `laugh`, `emphasis`, `question`
- 커스텀 이모지: 이모지 문자열 직접 입력

**내부 코드 매핑:**
- 추가: 2000–2006 (`associated_message_type`)
- 제거: 3000–3006

---

### 4.6 `rpc` — JSON-RPC 2.0 서버

프로그래밍 방식의 통합을 위한 JSON-RPC 2.0 서버를 실행한다.

```
imsg rpc [--db <path>]
```

**전송 방식:** stdin/stdout, 한 줄에 하나의 JSON 객체 (JSON Lines)

**RPC 메서드:**

| 메서드 | 설명 |
|--------|------|
| `chats.list` | 대화 목록 조회 |
| `messages.history` | 메시지 이력 조회 |
| `watch.subscribe` | 실시간 메시지 스트림 구독 (notification으로 수신) |
| `watch.unsubscribe` | 스트림 구독 해제 |
| `send` | 메시지 전송 |
| `react` | 리액션 전송 |

**프로토콜:** JSON-RPC 2.0 사양을 따르며, `watch.subscribe` 구독 시 새 메시지가 notification 형태로 전달된다.

---

### 4.7 Global Options

모든 커맨드에 적용되는 옵션:

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `--db` | String | `~/Library/Messages/chat.db` | 데이터베이스 파일 경로 |
| `--version`, `-V` | Bool | - | 버전 정보 출력 |
| `--help`, `-h` | Bool | - | 도움말 출력 |

---

## 5. Data Models

### 5.1 Chat

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | Int64 | 대화 고유 ID (chat 테이블 ROWID) |
| `identifier` | String | 대화 식별자 (예: `+14155551212`, `chat123456`) |
| `name` | String | 대화 표시 이름 |
| `service` | String | 서비스 종류 (`iMessage`, `SMS`) |
| `last_message_at` | ISO8601 | 마지막 메시지 일시 |

**그룹 대화 식별:** identifier에 `;+;` 또는 `;-;`가 포함된 경우 그룹 대화이다.

### 5.2 Message

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | Int64 | 메시지 고유 ID (message 테이블 ROWID) |
| `chat_id` | Int64 | 소속 대화 ID |
| `guid` | String | 메시지 GUID |
| `sender` | String | 발신자 핸들 |
| `is_from_me` | Bool | 자신이 보낸 메시지 여부 |
| `text` | String | 메시지 본문 |
| `created_at` | ISO8601 | 메시지 생성 일시 |
| `reply_to_guid` | String? | 답장 대상 메시지 GUID |
| `destination_caller_id` | String? | 수신 측 caller ID |
| `attachments` | [Attachment] | 첨부파일 메타데이터 배열 |
| `reactions` | [Reaction] | 리액션 배열 |

### 5.3 Attachment

| 필드 | 타입 | 설명 |
|------|------|------|
| `filename` | String | 파일명 |
| `transfer_name` | String | 전송 시 이름 |
| `uti` | String | Uniform Type Identifier |
| `mime_type` | String | MIME 타입 |
| `total_bytes` | Int64 | 파일 크기 (바이트) |
| `is_sticker` | Bool | 스티커 여부 |
| `original_path` | String | 원본 파일 경로 (틸드 확장됨) |
| `missing` | Bool | 파일 누락 여부 |

### 5.4 Reaction

| 필드 | 타입 | 설명 |
|------|------|------|
| `reaction_type` | String | 리액션 종류 (`love`, `like`, `dislike`, `laugh`, `emphasis`, `question`, 또는 커스텀 이모지) |
| `sender` | String | 리액션 발신자 |
| `is_from_me` | Bool | 자신의 리액션 여부 |
| `date` | ISO8601 | 리액션 일시 |

---

## 6. Database Access

### 6.1 대상 데이터베이스

- **경로:** `~/Library/Messages/chat.db` (SQLite)
- **접근 모드:** 읽기 전용 (`mode=ro`)
- **WAL 모드:** chat.db는 WAL(Write-Ahead Logging) 모드로 운영됨

### 6.2 스키마 호환성

다양한 macOS 버전의 스키마 차이를 자동 감지하고 적응한다:

| 기능 | 감지 대상 컬럼/테이블 |
|------|----------------------|
| attributed_body | `attributedBody` 컬럼 존재 여부 |
| 리액션 | `associated_message_type` 컬럼 |
| 스레드 | `thread_originator_guid` 컬럼 |
| 발신자 ID | `destination_caller_id` 컬럼 |
| 오디오 메시지 | 오디오 전사 관련 컬럼 |
| 첨부파일 user_info | attachment 테이블 확장 컬럼 |
| URL 풍선 | `balloon_bundle_id` 컬럼 |

---

## 7. Output Formats

### 7.1 텍스트 출력 (기본)

사람이 읽기 쉬운 형식으로 출력한다.

```
[2025-01-15 10:30:00] +14155551212: Hello!
[2025-01-15 10:31:00] me: Hi there!
```

### 7.2 JSON 출력 (`--json`)

JSON Lines 형식으로 출력한다 (한 줄에 하나의 JSON 객체).

```json
{"id":123,"chat_id":1,"guid":"...","sender":"+14155551212","is_from_me":false,"text":"Hello!","created_at":"2025-01-15T10:30:00Z","attachments":[],"reactions":[]}
```

---

## 8. Error Handling

| 에러 타입 | 상황 | 사용자 안내 |
|-----------|------|------------|
| `permissionDenied` | chat.db 접근 불가 | Full Disk Access 설정 안내 |
| `invalidISODate` | 잘못된 날짜 형식 | ISO8601 형식 예시 제공 |
| `invalidService` | 잘못된 서비스 이름 | `imessage`, `sms`, `auto` 중 선택 |
| `invalidChatTarget` | 대상 대화를 찾을 수 없음 | 유효한 핸들/chat ID 확인 |
| `appleScriptFailure` | AppleScript 실행 실패 | Automation 권한 확인 |
| `invalidReaction` | 잘못된 리액션 타입 | 지원되는 리액션 목록 제공 |
| `chatNotFound` | 존재하지 않는 chat ID | chat ID 확인 |

---

## 9. Dependencies

| 패키지 | 버전 | 용도 |
|--------|------|------|
| [SQLite.swift](https://github.com/nicklockwood/SQLite.swift) | ≥ 0.15.5 | Messages chat.db 읽기 전용 접근 |
| [PhoneNumberKit](https://github.com/marmelroy/PhoneNumberKit) | ≥ 4.2.5 | 전화번호 파싱 및 E.164 정규화 |
| [Commander](https://github.com/kylef/Commander) | ≥ 0.2.1 | CLI 인자 파싱 및 커맨드 라우팅 |
| ScriptingBridge | (system) | Messages.app AppleScript 제어 |

---

## 10. Build & Test

```bash
# 릴리스 빌드 (./bin/imsg 생성)
make build

# 디버그 빌드 및 실행
make imsg ARGS="chats --limit 5"

# 전체 테스트 실행
make test

# 코드 린트
make lint

# 코드 포맷팅
make format

# 빌드 아티팩트 정리
make clean
```

---

## 11. Security Considerations

- 데이터베이스에 대한 쓰기 작업을 일절 수행하지 않는다 (`mode=ro`).
- 메시지 전송은 macOS 권한 시스템(Automation)을 통해 제어된다.
- Private API를 사용하지 않으므로 macOS 업데이트에 의한 호환성 문제가 최소화된다.
- 첨부파일의 실제 내용은 복사하지 않고 메타데이터만 출력한다.
