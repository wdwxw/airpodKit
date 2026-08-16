import Combine
import Foundation

/// Wires the button monitor to the shortcut store: on a mapped button press,
/// consume the original event and synthesize the configured keystroke; if
/// unmapped, let the system's default behavior happen.
///
/// `RemoteButtonMonitor.start()` can only succeed once Accessibility +
/// Input Monitoring are both granted, and can go dead if a permission is
/// later revoked. We watch `PermissionsManager` continuously (no dedup) and
/// start/stop the monitor to match, instead of only trying once at launch.
enum RemapEngine {
    private static var permissionsCancellable: AnyCancellable?
    /// Tracks mapped presses whose down event reached us. On newer macOS
    /// versions, rcd can consume a media-key down event before the tap sees it;
    /// an otherwise-unpaired up event is then used as a one-shot fallback.
    private static var pendingMappedPresses: Set<RemoteButton> = []

    private static func resetPendingPresses() {
        pendingMappedPresses.removeAll()
    }

    static func start() {
        DebugLog.log("=== AirPodKit launched (pid \(ProcessInfo.processInfo.processIdentifier)) ===")

        // AirPodKit is a shortcut remapper, not a media player. Claiming Now
        // Playing globally can steal ordinary media controls from Music,
        // Spotify, and browser players. The launch guard below handles the
        // remaining Music fallback without pretending to be a player.
        MusicLaunchGuard.activate()

        RemoteButtonMonitor.shared.onButtonPress = { button, isDown in
            if isDown {
                guard let shortcut = ShortcutStore.shared.shortcut(for: button) else {
                    DebugLog.log("RemapEngine: \(button) has no mapping, letting default behavior happen")
                    return false
                }

                pendingMappedPresses.insert(button)
                if button == .center {
                    MusicLaunchGuard.noteCenterPressHandled()
                }
                DebugLog.log("RemapEngine: synthesizing \(shortcut.displayString) for \(button)")
                KeystrokeSynthesizer.post(shortcut)
                return true
            }

            // A normal mapped press has already been synthesized on down; its
            // up half is consumed only. If down was swallowed upstream, this
            // up event is the only signal available, so synthesize once here.
            if pendingMappedPresses.remove(button) != nil {
                return true
            }

            guard let shortcut = ShortcutStore.shared.shortcut(for: button) else {
                DebugLog.log("RemapEngine: \(button) has no mapping, letting default behavior happen")
                return false
            }

            if button == .center {
                MusicLaunchGuard.noteCenterPressHandled()
            }
            DebugLog.log("RemapEngine: no down event for \(button); synthesizing on up as fallback")
            KeystrokeSynthesizer.post(shortcut)
            return true
        }

        let permissions = PermissionsManager.shared
        permissionsCancellable = permissions.$accessibilityGranted
            .combineLatest(permissions.$inputMonitoringGranted)
            .map { $0 && $1 }
            .receive(on: DispatchQueue.main)
            .sink { allGranted in
                if allGranted {
                    RemoteButtonMonitor.shared.start()
                } else {
                    resetPendingPresses()
                    RemoteButtonMonitor.shared.stop()
                }
            }
    }
}
