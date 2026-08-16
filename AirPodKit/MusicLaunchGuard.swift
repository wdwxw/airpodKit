import AppKit

/// Last resort for the "macOS launches Music.app for Play/Pause anyway"
/// problem (see CLAUDE.md — `com.apple.rcd` sends the TogglePlayPause
/// command straight to `mediaremoted` outside any path we can intercept,
/// and registering as a `MPRemoteCommandCenter`/`MPNowPlayingInfoCenter`
/// candidate via `NowPlayingClaim` makes us *eligible* but doesn't win
/// mediaremoted's — undocumented — arbitration over Music). If Music.app
/// launches within a couple seconds of us having just handled a mapped
/// button press, assume it's this fallback and terminate it immediately.
enum MusicLaunchGuard {
    private static let musicBundleID = "com.apple.Music"
    private static let window: TimeInterval = 2.0

    private static var lastMappedPressAt: Date?
    private static var observer: NSObjectProtocol?

    static func noteMappedPressHandled() {
        lastMappedPressAt = Date()
    }

    static func activate() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                app.bundleIdentifier == musicBundleID,
                let pressedAt = lastMappedPressAt,
                Date().timeIntervalSince(pressedAt) < window
            else { return }

            DebugLog.log("MusicLaunchGuard: Music.app launched right after a mapped press — terminating it")
            app.forceTerminate()
        }
    }
}
