import Foundation
import KTalkCore

/// Shared database open helper.
func openDatabase(dbPath: String?, key: String?) throws -> DatabaseReader {
    let path: String
    let secureKey: String

    if let dbPath {
        path = dbPath
        guard let k = key else {
            throw KTalkError.databaseOpenFailed("--key option is required")
        }
        secureKey = k
    } else {
        let uuid = try DeviceInfo.platformUUID()

        // Standard path: derive dbName from userId
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

        // Fallback: discover DB file and try candidate userId keys
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
                throw KTalkError.databaseOpenFailed("Could not find a valid encryption key")
            }
            path = discoveredPath
            secureKey = k
        }
    }

    let reader = DatabaseReader(databasePath: path)
    try reader.open(key: secureKey)
    return reader
}

/// Formats a Date into a human-readable string.
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
