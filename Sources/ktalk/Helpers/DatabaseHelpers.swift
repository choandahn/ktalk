import Foundation
import KTalkCore

/// 공유 데이터베이스 열기 헬퍼.
func openDatabase(dbPath: String?, key: String?) throws -> DatabaseReader {
    let path: String
    let secureKey: String

    if let dbPath {
        path = dbPath
        guard let k = key else {
            throw KTalkError.databaseOpenFailed("--key 옵션이 필요합니다")
        }
        secureKey = k
    } else {
        let uuid = try DeviceInfo.platformUUID()

        // 표준 경로: userId → dbName 파생
        if let uid = try? DeviceInfo.userId() {
            let dbName = KeyDerivation.databaseName(userId: uid, uuid: uuid)
            let candidates = [
                "\(DeviceInfo.containerPath)/\(dbName)",
                "\(DeviceInfo.containerPath)/\(dbName).db",
            ]
            if let found = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                let k = key ?? KeyDerivation.secureKey(userId: uid, uuid: uuid)
                let reader = DatabaseReader(databasePath: found)
                try reader.open(key: k)
                return reader
            }
        }

        // 폴백: DB 파일 탐색 후 후보 userId로 키 시도
        guard let discoveredPath = DeviceInfo.discoverDatabaseFile() else {
            let uid = try DeviceInfo.userId()
            let dbName = KeyDerivation.databaseName(userId: uid, uuid: try DeviceInfo.platformUUID())
            throw KTalkError.databaseNotFound("\(DeviceInfo.containerPath)/\(dbName)")
        }

        if let k = key {
            path = discoveredPath
            secureKey = k
        } else {
            var candidates = (try? DeviceInfo.userId()).map { [$0] } ?? [Int]()
            candidates += DeviceInfo.candidateUserIds().filter { !candidates.contains($0) }

            var foundKey: String?
            for uid in candidates {
                let candidateKey = KeyDerivation.secureKey(userId: uid, uuid: uuid)
                let reader = DatabaseReader(databasePath: discoveredPath)
                if (try? reader.open(key: candidateKey)) != nil {
                    reader.close()
                    foundKey = candidateKey
                    break
                }
            }

            guard let k = foundKey else {
                throw KTalkError.databaseOpenFailed("올바른 암호화 키를 찾을 수 없습니다")
            }
            path = discoveredPath
            secureKey = k
        }
    }

    let reader = DatabaseReader(databasePath: path)
    try reader.open(key: secureKey)
    return reader
}

/// Date를 사람이 읽기 쉬운 형식으로 포맷합니다.
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        formatter.dateFormat = "HH:mm"
    } else if calendar.isDateInYesterday(date) {
        return "yesterday"
    } else {
        formatter.dateFormat = "MM/dd"
    }
    return formatter.string(from: date)
}
