import CommonCrypto
import CSQLCipher
import Foundation

/// Extracts the device UUID and KakaoTalk user ID from the local system.
public enum DeviceInfo {

    /// Retrieves the IOPlatformUUID from IORegistry.
    public static func platformUUID() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-rd1", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard let range = output.range(of: #""IOPlatformUUID" = "([^"]+)""#, options: .regularExpression),
              let uuidRange = output[range].range(
                of: #"[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"#,
                options: .regularExpression
              )
        else {
            throw KTalkError.uuidNotFound
        }
        return String(output[uuidRange])
    }

    /// Path to the KakaoTalk container data directory.
    public static var containerPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Containers/com.kakao.KakaoTalkMac/Data/Library/Application Support/com.kakao.KakaoTalkMac"
    }

    /// Path to the container preferences plist.
    public static var preferencesPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let prefDir = "\(home)/Library/Containers/com.kakao.KakaoTalkMac/Data/Library/Preferences"
        if let files = try? FileManager.default.contentsOfDirectory(atPath: prefDir) {
            for file in files
                where file.hasPrefix("com.kakao.KakaoTalkMac.")
                    && file.hasSuffix(".plist")
                    && file != "com.kakao.KakaoTalkMac.plist" {
                return "\(prefDir)/\(file)"
            }
        }
        return "\(prefDir)/com.kakao.KakaoTalkMac.plist"
    }

    /// Extracts the user ID from the KakaoTalk preferences plist.
    ///
    /// Tries the following strategies in order:
    /// 0. talk-user-id HTTP header from Cache.db (most reliable)
    /// 1. Common suffix of FSChatWindowTransparency keys (legacy)
    /// 2. Direct key lookup (userId, user_id, etc.)
    /// 3. Reverse SHA-512 hash from plist revision key
    /// 4. Common suffix of FSChatWindowFrame_ keys
    public static func userId() throws -> Int {
        // Strategy 0: Read talk-user-id header from Cache.db
        if let id = userIdFromCacheDB() {
            return id
        }

        let plistPath = preferencesPath
        guard FileManager.default.fileExists(atPath: plistPath) else {
            throw KTalkError.plistNotFound(plistPath)
        }

        let url = URL(fileURLWithPath: plistPath)
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw KTalkError.plistParseError
        }

        // Strategy 1: Extract common suffix from FSChatWindowTransparency keys
        let transparencyPrefix = "FSChatWindowTransparency"
        let fsChatKeys = plist.keys.filter { $0.hasPrefix(transparencyPrefix) }
        if fsChatKeys.count >= 2 {
            let suffixes = fsChatKeys.map { String($0.dropFirst(transparencyPrefix.count)) }
            if let commonSuffix = longestCommonSuffix(suffixes), let id = Int(commonSuffix) {
                return id
            }
        }

        // Strategy 2: Direct key lookup
        let candidateKeys = ["userId", "user_id", "KAKAO_USER_ID", "userID"]
        for key in candidateKeys {
            if let id = plist[key] as? Int { return id }
            if let str = plist[key] as? String, let id = Int(str) { return id }
        }

        // Strategy 3: Reverse SHA-512 hash from plist revision key
        if let hash = activeAccountHash(from: plist) {
            if let id = recoverUserIdFromSHA512(hexHash: hash) {
                return id
            }
        }

        // Strategy 4: FSChatWindowFrame_ common suffix
        let framePrefix = "NSWindow Frame FSChatWindowFrame_"
        let frameKeys = plist.keys.filter { $0.hasPrefix(framePrefix) }
        if frameKeys.count >= 2 {
            let suffixes = frameKeys.map { String($0.dropFirst(framePrefix.count)) }
            if let commonSuffix = longestCommonSuffix(suffixes), let id = Int(commonSuffix) {
                return id
            }
        }

        // Strategy 5: AlertKakaoIDsList — return immediately if only one candidate
        if let ids = plist["AlertKakaoIDsList"] as? [Any] {
            let candidates = ids.compactMap { item -> Int? in
                if let id = item as? Int { return id > 0 ? id : nil }
                if let str = item as? String, let id = Int(str) { return id > 0 ? id : nil }
                return nil
            }
            if let id = candidates.first { return id }
        }

        throw KTalkError.userIdNotFound(Array(plist.keys))
    }

    /// Reads candidate user IDs from the plist's AlertKakaoIDsList.
    public static func candidateUserIds() -> [Int] {
        let plistPath = preferencesPath
        guard FileManager.default.fileExists(atPath: plistPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let ids = plist["AlertKakaoIDsList"] as? [Any] else { return [] }

        return ids.compactMap { item -> Int? in
            if let id = item as? Int { return id > 0 ? id : nil }
            if let str = item as? String, let id = Int(str) { return id > 0 ? id : nil }
            return nil
        }
    }

    /// Searches the container for a 78-character hex filename and returns the database file path.
    public static func discoverDatabaseFile() -> String? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: containerPath) else { return nil }
        // nonisolated(unsafe) not needed in Swift 6 — try! is safe here as it's a compile-time pattern
        guard let hexPattern = try? NSRegularExpression(pattern: "^[0-9a-f]{78}$") else { return nil }
        for entry in entries {
            let range = NSRange(entry.startIndex..., in: entry)
            if hexPattern.firstMatch(in: entry, range: range) != nil {
                return "\(containerPath)/\(entry)"
            }
        }
        // Also check for hex files with .db extension
        guard let hexDbPattern = try? NSRegularExpression(pattern: "^[0-9a-f]{78}\\.db$") else { return nil }
        for entry in entries {
            let range = NSRange(entry.startIndex..., in: entry)
            if hexDbPattern.firstMatch(in: entry, range: range) != nil {
                return "\(containerPath)/\(entry)"
            }
        }
        return nil
    }

    /// Returns the number of database files in the container.
    public static func countDatabaseFiles() -> Int {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: containerPath) else { return 0 }
        guard let hexPattern = try? NSRegularExpression(pattern: "^[0-9a-f]{78}(\\.db)?$") else { return 0 }
        return entries.filter { entry in
            let range = NSRange(entry.startIndex..., in: entry)
            return hexPattern.firstMatch(in: entry, range: range) != nil
        }.count
    }

    /// Extracts the SHA-512 hash of the active account from plist revision keys.
    public static func activeAccountHash() -> String? {
        let plistPath = preferencesPath
        guard FileManager.default.fileExists(atPath: plistPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return activeAccountHash(from: plist)
    }

    /// Brute-force recovers the preimage of a SHA-512 hash.
    /// KakaoTalk stores SHA-512(userId) hex in plist keys.
    /// userId is a small integer, so the search completes quickly (10-second timeout).
    public static func recoverUserIdFromSHA512(hexHash: String) -> Int? {
        guard hexHash.count == 128 else { return nil }
        var targetBytes = [UInt8](repeating: 0, count: 64)
        let hexChars = Array(hexHash)
        for i in 0..<64 {
            guard let byte = UInt8(String(hexChars[i*2...i*2+1]), radix: 16) else { return nil }
            targetBytes[i] = byte
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let maxId = 1_000_000_000
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))

        for i in 0..<maxId {
            let s = String(i)
            let data = Array(s.utf8)
            CC_SHA512(data, CC_LONG(data.count), &hash)
            if hash == targetBytes { return i }
            if i % 5_000_000 == 0 && i > 0 {
                if CFAbsoluteTimeGetCurrent() - startTime > 10 { return nil }
            }
        }
        return nil
    }

    // MARK: - Cache.db userId Extraction

    /// Reads the talk-user-id HTTP header from NSURLCache in Cache.db.
    /// The KakaoTalk client includes the userId in the talk-user-id header on API requests,
    /// and macOS NSURLCache stores this in Cache.db.
    private static func userIdFromCacheDB() -> Int? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cacheDBPath = "\(home)/Library/Containers/com.kakao.KakaoTalkMac/Data/Library/Caches/Cache.db"
        guard FileManager.default.fileExists(atPath: cacheDBPath) else { return nil }

        var db: OpaquePointer?
        guard sqlite3_open_v2(cacheDBPath, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT b.request_object FROM cfurl_cache_response r
            JOIN cfurl_cache_blob_data b ON r.entry_ID = b.entry_ID
            WHERE r.request_key LIKE '%/me/%' OR r.request_key LIKE '%talk-user-id%'
            LIMIT 50
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let blob = sqlite3_column_blob(stmt, 0) else { continue }
            let len = sqlite3_column_bytes(stmt, 0)
            let data = Data(bytes: blob, count: Int(len))

            // Search for talk-user-id value in bplist-prefixed plists
            if let userId = extractTalkUserIdFromPlist(data) {
                return userId
            }
            // Also search in plain text
            if let text = String(data: data, encoding: .utf8),
               let userId = extractTalkUserIdFromText(text) {
                return userId
            }
        }
        return nil
    }

    private static func extractTalkUserIdFromPlist(_ data: Data) -> Int? {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) else {
            return nil
        }
        return searchForTalkUserId(in: plist)
    }

    private static func searchForTalkUserId(in obj: Any) -> Int? {
        if let dict = obj as? [String: Any] {
            if let val = dict["talk-user-id"] {
                if let id = val as? Int, id > 0 { return id }
                if let str = val as? String, let id = Int(str), id > 0 { return id }
            }
            for (_, v) in dict {
                if let id = searchForTalkUserId(in: v) { return id }
            }
        } else if let arr = obj as? [Any] {
            for item in arr {
                if let id = searchForTalkUserId(in: item) { return id }
            }
        }
        return nil
    }

    private static func extractTalkUserIdFromText(_ text: String) -> Int? {
        guard let range = text.range(of: #"talk-user-id[:\s]+(\d+)"#, options: .regularExpression) else {
            return nil
        }
        let match = text[range]
        guard let numRange = match.range(of: #"\d+"#, options: .regularExpression) else { return nil }
        return Int(match[numRange])
    }

    // MARK: - Private Helpers

    private static func activeAccountHash(from plist: [String: Any]) -> String? {
        // SHA-512("0") = hash of the default/empty account
        let emptyHash = "31bca02094eb78126a517b206a88c73cfa9ec6f704c7030d18212cace820f025f00bf0ea68dbf3f3a5436ca63b53bf7bf80ad8d5de7d8359d0b7fed9dbc3ab99"
        let prefix = "DESIGNATEDFRIENDSREVISION:"
        for (key, val) in plist where key.hasPrefix(prefix) {
            let hash = String(key.dropFirst(prefix.count))
            if hash == emptyHash { continue }
            let intVal: Int
            if let v = val as? Int { intVal = v }
            else if let v = val as? Double { intVal = Int(v) }
            else { intVal = 0 }
            if intVal != 0 { return hash }
        }
        return nil
    }

    private static func longestCommonSuffix(_ strings: [String]) -> String? {
        guard let first = strings.first else { return nil }
        let reversed = strings.map { String($0.reversed()) }
        var commonLen = 0
        for i in reversed[0].indices {
            let ch = reversed[0][i]
            if reversed.allSatisfy({ i < $0.endIndex && $0[i] == ch }) {
                commonLen += 1
            } else {
                break
            }
        }
        guard commonLen > 0 else { return nil }
        return String(first.suffix(commonLen))
    }
}

