import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

/// Owns the explicit menu-bar status item and the permissions onboarding
/// window. The status item is kept alive by the app delegate for the whole
/// lifetime of the menu-bar utility.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    private var onboardingWindow: NSWindow?
    private var cancellable: AnyCancellable?
    private var activationObserver: NSObjectProtocol?
    private var commandQMonitor: Any?
    private var commandQTerminationRequested = false
    private var menuRequestedTermination = false
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        installCommandQMonitor()

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

    private func installCommandQMonitor() {
        commandQMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.recordCommandQIfNeeded(event)
            return event
        }
    }

    private func recordCommandQIfNeeded(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard event.keyCode == UInt16(kVK_ANSI_Q), modifiers == .command else { return }

        // A shortcut field must still be able to record ⌘Q. The local monitor
        // sees the key before the field's own key-equivalent handling.
        guard !(NSApp.keyWindow?.firstResponder is RecorderNSView) else { return }

        commandQTerminationRequested = true
        DebugLog.log("Command-Q termination request detected")

        // If AppKit handles the key without asking us to terminate, do not let
        // this one key press authorize a later unrelated termination request.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, !self.menuRequestedTermination else { return }
            self.commandQTerminationRequested = false
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
        // Let the popover track the SwiftUI content's actual (dynamic)
        // height instead of a hard-coded size — PopoverRootView's height
        // varies with whether the permissions onboarding card is showing
        // and with shortcut label lengths, and a fixed contentSize would
        // just clip the overflow instead of resizing.
        hostingController.sizingOptions = [.preferredContentSize]
        let popover = NSPopover()
        popover.contentViewController = hostingController
        popover.behavior = .transient
        popover.animates = true
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
        DebugLog.log("Explicit menu termination requested")
        menuRequestedTermination = true
        popover?.performClose(nil)

        // NSPopover is backed by a tracking loop. Defer termination until the
        // button event has finished so the tracking loop cannot swallow the
        // application termination request.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.menuRequestedTermination else { return }
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard menuRequestedTermination || commandQTerminationRequested else {
            DebugLog.log("Ignored implicit application termination request")
            return .terminateCancel
        }
        DebugLog.log(
            menuRequestedTermination
                ? "Accepted explicit menu termination request"
                : "Accepted Command-Q termination request"
        )
        return .terminateNow
    }

    deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        if let commandQMonitor {
            NSEvent.removeMonitor(commandQMonitor)
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
