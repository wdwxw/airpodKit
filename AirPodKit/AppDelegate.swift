import AppKit
import Combine
import SwiftUI

/// Shows a real, front-and-center window guiding the user through granting
/// Accessibility + Input Monitoring every time the app launches while
/// they're not both granted yet — the menu bar popover alone isn't enough
/// since `LSUIElement` apps have no Dock icon and `MenuBarExtra` has no
/// programmatic way to open its popover, so users could easily never
/// notice it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var cancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let permissions = PermissionsManager.shared
        cancellable = permissions.$accessibilityGranted
            .combineLatest(permissions.$inputMonitoringGranted)
            .map { $0 && $1 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                if granted {
                    self?.closeOnboardingWindow()
                } else {
                    self?.showOnboardingWindow()
                }
            }
    }

    private func showOnboardingWindow() {
        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(
            rootView: PermissionsOnboardingView(permissions: PermissionsManager.shared)
                .frame(width: 320)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "AirPodKit 需要授权"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        onboardingWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
}
