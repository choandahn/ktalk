import AppKit
import ApplicationServices
import Foundation

/// KakaoTalk 앱의 관찰 상태
public enum AppState: String, Sendable {
    case notRunning
    case launching
    case loginScreen
    case loggedIn
    case updateRequired
    case unknown
}

/// KakaoTalk.app 라이프사이클 관리: 실행, 상태 감지, 준비 확인
public enum AppLifecycle {

    public static let bundleId = KakaoAutomator.bundleId
    public static let appPath = "/Applications/KakaoTalk.app"

    // MARK: - State Detection

    public static func isRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
    }

    public static func detectState(aggressive: Bool = true) -> AppState {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else {
            return .notRunning
        }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windows = AXHelpers.windows(axApp)

        if windows.isEmpty && aggressive {
            app.activate()
            Thread.sleep(forTimeInterval: 0.5)
            windows = AXHelpers.windows(axApp)
        }

        if windows.isEmpty && aggressive {
            showMainWindow(axApp)
            Thread.sleep(forTimeInterval: 1.0)
            windows = AXHelpers.windows(axApp)
        }

        let realWindows = windows.filter { AXHelpers.role($0) == "AXWindow" }
        if !realWindows.isEmpty {
            if let mainWindow = realWindows.first(where: { AXHelpers.identifier($0) == "Main Window" }) {
                return classifyWindow(mainWindow)
            }
            return .loggedIn
        }

        if windows.isEmpty || !realWindows.isEmpty == false {
            let menuState = checkStatusBarMenu()
            if menuState != .unknown {
                return menuState
            }
        }

        if windows.isEmpty {
            return .launching
        }

        return .unknown
    }

    private static func classifyWindow(_ window: AXUIElement) -> AppState {
        let id = AXHelpers.identifier(window)
        if id == "Main Window" {
            let title = AXHelpers.title(window) ?? ""
            if title.lowercased().contains("log in") || title == "로그인" {
                return .loginScreen
            }
            if AXHelpers.findFirst(window, role: "AXImage", identifier: "Logo") != nil {
                return .loginScreen
            }
            if AXHelpers.chatListTable(window) != nil {
                return .loggedIn
            }
            return .loggedIn
        }
        if AXHelpers.findFirst(window, role: "AXButton", text: "update") != nil ||
           AXHelpers.findFirst(window, role: "AXButton", text: "업데이트") != nil {
            return .updateRequired
        }
        return .loginScreen
    }

    private static func checkStatusBarMenu() -> AppState {
        let script = """
        tell application "System Events"
            tell process "KakaoTalk"
                try
                    click menu bar item 1 of menu bar 2
                    delay 0.3
                    set menuItems to name of every menu item of menu 1 of menu bar item 1 of menu bar 2
                    key code 53
                    return menuItems as text
                on error
                    return "error"
                end try
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if output.contains("Log out") || output.contains("로그아웃") { return .loggedIn }
            if output.contains("Log in") || output.contains("로그인") { return .loginScreen }
        } catch {}
        return .unknown
    }

    // MARK: - Launch

    public static func launch() throws {
        guard !isRunning() else { return }

        let appURL = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw KTalkError.appNotInstalled
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        let semaphore = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var launchError: (any Error)?

        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            launchError = error
            semaphore.signal()
        }
        semaphore.wait()

        if let error = launchError {
            throw LifecycleError.launchFailed(error.localizedDescription)
        }
    }

    // MARK: - Wait Utilities

    public static func waitForAnyState(
        _ targets: Set<AppState>,
        timeout: TimeInterval = 30.0,
        pollInterval: TimeInterval = 0.5
    ) -> AppState {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = detectState(aggressive: false)
            if targets.contains(current) { return current }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return detectState(aggressive: false)
    }

    // MARK: - Ensure Ready

    public static func ensureReady(credentials: CredentialStore? = nil) throws {
        let state = detectState()

        switch state {
        case .loggedIn:
            try ensureWindowVisible()
            return

        case .notRunning:
            fputs("Launching KakaoTalk...\n", stderr)
            try launch()
            let afterLaunch = waitForAnyState([.loggedIn, .loginScreen, .updateRequired], timeout: 15.0)
            if afterLaunch == .loggedIn { return }
            if afterLaunch == .updateRequired { throw LifecycleError.updateRequired }
            if afterLaunch == .loginScreen {
                try attemptLogin(credentials: credentials)
                return
            }
            throw LifecycleError.launchTimeout

        case .launching:
            let afterWait = waitForAnyState([.loggedIn, .loginScreen, .updateRequired], timeout: 15.0)
            if afterWait == .loggedIn { return }
            if afterWait == .loginScreen {
                try attemptLogin(credentials: credentials)
                return
            }
            throw LifecycleError.launchTimeout

        case .loginScreen:
            try attemptLogin(credentials: credentials)

        case .updateRequired:
            throw LifecycleError.updateRequired

        case .unknown:
            throw LifecycleError.unknownState
        }
    }

    // MARK: - Private

    private static func ensureWindowVisible() throws {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first else { return }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        let windows = AXHelpers.windows(axApp)
        let hasRealMainWindow = windows.contains {
            AXHelpers.role($0) == "AXWindow" && AXHelpers.identifier($0) == "Main Window"
        }
        if hasRealMainWindow { return }

        fputs("Opening KakaoTalk window...\n", stderr)
        showMainWindow(axApp)
        Thread.sleep(forTimeInterval: 1.5)

        let deadline = Date().addingTimeInterval(10.0)
        while Date() < deadline {
            let currentWindows = AXHelpers.windows(axApp)
            if currentWindows.contains(where: {
                AXHelpers.role($0) == "AXWindow" && AXHelpers.identifier($0) == "Main Window"
            }) { return }
            app.activate()
            Thread.sleep(forTimeInterval: 1.0)
        }
        fputs("Warning: Could not get a standard AXWindow. Proceeding anyway.\n", stderr)
    }

    private static func attemptLogin(credentials: CredentialStore?) throws {
        guard let creds = credentials, let email = creds.email, let password = creds.password else {
            throw LifecycleError.loginRequired
        }
        try LoginAutomator.login(email: email, password: password)
    }

    /// AppleScript으로 상태 표시줄 메뉴에서 KakaoTalk 창을 엽니다.
    private static func showMainWindow(_ axApp: AXUIElement) {
        let script = """
        tell application "System Events"
            tell process "KakaoTalk"
                set frontmost to true
                delay 0.3
                try
                    click menu bar item 1 of menu bar 2
                    delay 0.3
                    click menu item "Open KakaoTalk" of menu 1 of menu bar item 1 of menu bar 2
                on error
                    try
                        click menu item "카카오톡 열기" of menu 1 of menu bar item 1 of menu bar 2
                    end try
                end try
            end tell
        end tell
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

public enum LifecycleError: Error, CustomStringConvertible {
    case launchFailed(String)
    case launchTimeout
    case loginRequired
    case loginFailed(String)
    case otpRequired
    case updateRequired
    case wrongPassword
    case networkError
    case unknownState

    public var description: String {
        switch self {
        case .launchFailed(let msg): return "Failed to launch KakaoTalk: \(msg)"
        case .launchTimeout: return "KakaoTalk launched but did not become ready within timeout"
        case .loginRequired: return "No credentials stored. Run: ktalk login"
        case .loginFailed(let msg): return "Login failed: \(msg)"
        case .otpRequired: return "KakaoTalk is requesting 2FA. Complete login manually."
        case .updateRequired: return "KakaoTalk requires an update. Please update manually."
        case .wrongPassword: return "Login failed: incorrect email or password"
        case .networkError: return "Login failed: network error"
        case .unknownState: return "KakaoTalk is in an unrecognized state"
        }
    }
}
