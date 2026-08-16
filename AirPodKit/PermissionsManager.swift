import AppKit
import ApplicationServices
import IOKit.hid

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var accessibilityGranted: Bool = false
    @Published var inputMonitoringGranted: Bool = false

    var allGranted: Bool { accessibilityGranted && inputMonitoringGranted }

    private var timer: Timer?

    private init() {
        refresh()
        // Proactively prompt on every launch until both are granted, rather
        // than waiting for the user to notice and open the popover.
        if !accessibilityGranted { requestAccessibility() }
        if !inputMonitoringGranted { requestInputMonitoring() }

        let pollTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        // .common (not just .default) so polling keeps running while a
        // menu/window tracking loop or modal alert is active.
        RunLoop.main.add(pollTimer, forMode: .common)
        timer = pollTimer
    }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        inputMonitoringGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    func requestAccessibility() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }
}
