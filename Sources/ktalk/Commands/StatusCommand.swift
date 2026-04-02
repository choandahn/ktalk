import ArgumentParser
import Foundation
import KTalkCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "KakaoTalk 설치 및 연결 상태 확인"
    )

    func run() throws {
        let appPath = "/Applications/KakaoTalk.app"
        let containerExists = FileManager.default.fileExists(atPath: DeviceInfo.containerPath)
        let preferencesPath = DeviceInfo.preferencesPath
        let preferencesExist = FileManager.default.fileExists(atPath: preferencesPath)

        print("KakaoTalk Status")
        print("================")
        print("앱 설치:            \(FileManager.default.fileExists(atPath: appPath) ? "Yes" : "No")")
        print("컨테이너 존재:       \(containerExists ? "Yes" : "No")")
        print("Preferences 존재:   \(preferencesExist ? "Yes" : "No")")

        // Device UUID
        do {
            let uuid = try DeviceInfo.platformUUID()
            print("Device UUID:        \(uuid)")
        } catch {
            print("Device UUID:        ERROR - \(error)")
        }

        // User ID
        do {
            let uid = try DeviceInfo.userId()
            print("User ID:            \(uid)")
        } catch {
            let candidates = DeviceInfo.candidateUserIds()
            if candidates.isEmpty {
                print("User ID:            NOT FOUND")
            } else {
                print("User ID:            NOT FOUND (후보: \(candidates.map(String.init).joined(separator: ", ")))")
            }
        }

        // 데이터베이스 파일
        if containerExists {
            let dbCount = DeviceInfo.countDatabaseFiles()
            print("DB 파일 수:          \(dbCount)")
            if let dbPath = DeviceInfo.discoverDatabaseFile() {
                let dbName = URL(fileURLWithPath: dbPath).lastPathComponent
                print("DB 파일명:           \(dbName)")
            }
        }

        // 계정 해시
        if let hash = DeviceInfo.activeAccountHash() {
            print("계정 해시:           \(hash.prefix(40))...")
        }

        // 권한
        print("\n권한")
        print("----")
        let hasFullDisk = containerExists && FileManager.default.isReadableFile(atPath: DeviceInfo.containerPath)
        print("Full Disk Access:   \(hasFullDisk ? "허용된 것으로 보임" : "필요할 수 있음")")

        // 앱 상태
        print("\n앱 상태")
        print("-------")
        let appState = AppLifecycle.detectState()
        print("상태:               \(appState.rawValue)")
        let creds = CredentialStore()
        print("저장된 자격증명:      \(creds.hasCredentials ? "Yes" : "No")")
    }
}
