import AppKit

/// Last-resort guard for the macOS media-routing path that can launch Music.app
/// even after the NX_SYSDEFINED event was consumed. The notification is
/// intentionally `willLaunch`, rather than `didLaunch`, so Music is terminated
/// before it finishes starting and the user does not see a launch-then-close
/// flash.
enum MusicLaunchGuard {
    private static let musicBundleIDs: Set<String> = [
        "com.apple.Music",
        "com.apple.iTunes",
    ]
    private static let window: TimeInterval = 1.0

    private static var lastCenterPressAt: Date?
    private static var observer: NSObjectProtocol?

    static func noteCenterPressHandled() {
        lastCenterPressAt = Date()
    }

    static func activate() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleIdentifier = app.bundleIdentifier,
                musicBundleIDs.contains(bundleIdentifier),
                let pressedAt = lastCenterPressAt,
                Date().timeIntervalSince(pressedAt) < window
            else { return }

            // Consume the timestamp before terminating so a delayed or
            // unrelated launch notification cannot kill another Music launch.
            lastCenterPressAt = nil
            DebugLog.log("MusicLaunchGuard: \(bundleIdentifier) will launch after a mapped center press — terminating before startup")
            app.forceTerminate()
        }
    }
}
