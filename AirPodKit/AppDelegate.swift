import AppKit
import Combine
import SwiftUI

/// Shows a real, front-and-center window guiding the user through granting
/// Owns the explicit menu-bar status item and the permissions onboarding
/// window. The explicit NSStatusItem keeps the utility visible even when
/// SwiftUI's MenuBarExtra state is not restored correctly by macOS.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var onboardingWindow: NSWindow?
    private var cancellable: AnyCancellable?
    private var activationObserver: NSObjectProtocol?
    private var menuRequestedTermination = false
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

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

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main
        ) { _ in
            // TCC does not provide a reliable change notification. Refresh
            // when the user returns from System Settings or opens the app.
            PermissionsManager.shared.refresh()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else {
            DebugLog.log("Failed to create menu-bar status item")
            return
        }

        let image = NSImage(
            systemSymbolName: "airpods",
            accessibilityDescription: "AirPodKit"
        ) ?? NSImage(
            systemSymbolName: "headphones",
            accessibilityDescription: "AirPodKit"
        )

        if let image {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
        } else {
            // Keep the item discoverable even if a future macOS release
            // removes either SF Symbol used above.
            button.title = "AirPodKit"
        }
        button.toolTip = "AirPodKit"
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let hostingController = NSHostingController(rootView: PopoverRootView())
        let popover = NSPopover()
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 360)
        self.popover = popover

        DebugLog.log("Menu-bar status item created")
    }

    @objc private func togglePopover(_ sender: Any?) {
        DebugLog.log("Menu-bar status item clicked")
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Only the explicit menu item is allowed to quit the menu-bar utility.
    /// This prevents a Command-Q intended for another app from terminating
    /// AirPodKit when its onboarding window or popover is frontmost.
    func requestTerminationFromMenu() {
        menuRequestedTermination = true
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard menuRequestedTermination else {
            DebugLog.log("Ignored implicit application termination request")
            return .terminateCancel
        }
        return .terminateNow
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
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
