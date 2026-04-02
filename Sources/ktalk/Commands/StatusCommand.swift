import ArgumentParser
import Foundation
import KTalkCore

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check KakaoTalk installation and connection status"
    )

    func run() throws {
        let appPath = "/Applications/KakaoTalk.app"
        let containerExists = FileManager.default.fileExists(atPath: DeviceInfo.containerPath)
        let preferencesPath = DeviceInfo.preferencesPath
        let preferencesExist = FileManager.default.fileExists(atPath: preferencesPath)

        print("KakaoTalk Status")
        print("================")
        print("App installed:      \(FileManager.default.fileExists(atPath: appPath) ? "Yes" : "No")")
        print("Container exists:   \(containerExists ? "Yes" : "No")")
        print("Preferences exist:  \(preferencesExist ? "Yes" : "No")")

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
                print("User ID:            NOT FOUND (candidates: \(candidates.map(String.init).joined(separator: ", ")))")
            }
        }

        // Database files
        if containerExists {
            let dbCount = DeviceInfo.countDatabaseFiles()
            print("DB file count:      \(dbCount)")
            if let dbPath = DeviceInfo.discoverDatabaseFile() {
                let dbName = URL(fileURLWithPath: dbPath).lastPathComponent
                print("DB filename:        \(dbName)")
            }
        }

        // Account hash
        if let hash = DeviceInfo.activeAccountHash() {
            print("Account hash:       \(hash.prefix(40))...")
        }

        // Permissions
        print("\nPermissions")
        print("-----------")
        let hasFullDisk = containerExists && FileManager.default.isReadableFile(atPath: DeviceInfo.containerPath)
        print("Full Disk Access:   \(hasFullDisk ? "Appears granted" : "May be required")")

        // App State
        print("\nApp State")
        print("---------")
        let isRunning = AppLifecycle.isRunning()
        print("Running:            \(isRunning ? "Yes" : "No")")
        let creds = CredentialStore()
        print("Stored credentials: \(creds.hasCredentials ? "Yes" : "No")")
    }
}
