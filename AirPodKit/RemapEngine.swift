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

    static func start() {
        RemoteButtonMonitor.shared.onButtonPress = { button in
            guard let shortcut = ShortcutStore.shared.shortcut(for: button) else {
                return false
            }
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
                    RemoteButtonMonitor.shared.stop()
                }
            }
    }
}
