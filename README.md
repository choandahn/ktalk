# ktalk

macOS의 KakaoTalk 데이터베이스에 대한 CLI 인터페이스입니다. 채팅 조회, 메시지 검색, 실시간 스트리밍, 메시지 전송을 지원합니다.

## 요구사항

- macOS 14 (Sonoma) 이상
- KakaoTalk 설치 및 로그인 상태
- **Full Disk Access** 권한 허용 (시스템 설정 → 개인 정보 보호 및 보안 → 전체 디스크 접근권한)
- [Homebrew](https://brew.sh) 및 `sqlcipher`

## 설치

### Homebrew (추천)

```bash
brew tap choandahn/ktalk
brew install ktalk
```

### 소스에서 빌드

```bash
brew install sqlcipher
git clone https://github.com/choandahn/ktalk.git
cd ktalk
make build
sudo make install
```

## 사용법

### 시스템 상태 확인

```bash
ktalk status
```

### 대화 목록

```bash
ktalk chats
ktalk chats --limit 20
ktalk chats --json
```

### 메시지 히스토리

```bash
ktalk history --chat-id ID
ktalk history --chat-id ID --limit 50
ktalk history --chat-id ID --since 24h
ktalk history --chat-id ID --start 2024-01-01T00:00:00 --end 2024-01-31T23:59:59
ktalk history --chat-id ID --json
```

### 메시지 검색

```bash
ktalk search "검색어"
ktalk search "검색어" --limit 20
ktalk search "검색어" --json
```

### 실시간 스트리밍

```bash
ktalk watch
ktalk watch --chat-id ID
ktalk watch --interval 2
ktalk watch --json
```

### 메시지 전송

```bash
ktalk send --to "홍길동" --text "안녕하세요"
ktalk send --to "나와의 채팅" --text "메모" --self
```

### JSON-RPC 2.0 서버

```bash
ktalk rpc
```

### 자격증명 관리

```bash
ktalk login
ktalk login --status
ktalk login --clear
```

### Raw SQL 실행

```bash
ktalk query "SELECT * FROM NTChatRoom LIMIT 10"
```

### DB 스키마 출력

```bash
ktalk schema
```

## Makefile 커맨드

| 커맨드 | 설명 |
|--------|------|
| `make build` | Release 빌드 후 `./bin/ktalk`에 복사 |
| `make debug` | Debug 빌드 |
| `make test` | 테스트 실행 |
| `make run ARGS="chats"` | 개발 중 직접 실행 |
| `make install` | `/usr/local/bin/ktalk`에 설치 |
| `make clean` | 빌드 결과물 정리 |
| `make lint` | SwiftLint 실행 (설치된 경우) |
| `make format` | swift-format 실행 (설치된 경우) |

## 보안 고려사항

- KakaoTalk DB는 **읽기 전용(read-only)**으로만 접근합니다. 원본 데이터를 수정하지 않습니다.
- 메시지 전송은 macOS **Accessibility API(AX 자동화)**를 사용합니다. Private API를 사용하지 않습니다.
- DB 암호화 키는 기기 UUID와 사용자 ID에서 런타임에 유도되며, 디스크에 저장되지 않습니다.

## 라이선스

MIT
