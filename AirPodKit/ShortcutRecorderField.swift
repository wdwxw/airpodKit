import AppKit
import SwiftUI

struct ShortcutRecorderField: NSViewRepresentable {
    @Binding var shortcut: Shortcut?

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = { newShortcut in
            shortcut = newShortcut
        }
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.displayShortcut = shortcut
    }
}

final class RecorderNSView: NSView {
    /// How long to wait after the last relevant key event before
    /// committing the current candidate — a new event within the window
    /// (another modifier, or the base key finally landing) replaces the
    /// candidate and restarts the countdown.
    private static let commitDelay: TimeInterval = 1.0

    var onCapture: ((Shortcut) -> Void)?

    var displayShortcut: Shortcut? {
        didSet { needsDisplay = true }
    }

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    private var pendingShortcut: Shortcut? {
        didSet { needsDisplay = true }
    }

    /// Modifiers pressed at some point during the current recording
    /// session (not "currently held" — released modifiers stay counted so
    /// a solo tap-and-release still registers).
    private var capturedModifiers: Set<ModifierKey> = []
    private var capturedKeyCode: CGKeyCode?

    private var commitTimer: Timer?

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize { NSSize(width: 140, height: 22) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        beginRecording()
    }

    override func resignFirstResponder() -> Bool {
        cancelRecording()
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 { // Escape cancels
            cancelRecording()
            window?.makeFirstResponder(nil)
            return
        }

        capturedKeyCode = event.keyCode
        updateCandidateAndRestartTimer()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Return/Tab/Escape are normally intercepted by the window as key
        // equivalents (e.g. for a default/cancel button) before they ever
        // reach keyDown. While recording, claim them here first so they
        // land in our own capture logic instead.
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        guard let modifier = ModifierKey(keyCode: event.keyCode) else { return }
        // Only react to the key-down transition of this specific side; the
        // matching key-up transition is what lets a solo tap register (see
        // capturedModifiers doc comment) so it's intentionally ignored here.
        let isDown = (event.modifierFlags.rawValue & Self.deviceMask(for: modifier)) != 0
        guard isDown else { return }

        capturedModifiers.insert(modifier)
        updateCandidateAndRestartTimer()
    }

    private func beginRecording() {
        capturedModifiers = []
        capturedKeyCode = nil
        pendingShortcut = nil
        isRecording = true
    }

    private func updateCandidateAndRestartTimer() {
        if let keyCode = capturedKeyCode {
            pendingShortcut = .combo(modifiers: capturedModifiers, keyCode: keyCode)
        } else if capturedModifiers.count == 1, let only = capturedModifiers.first {
            pendingShortcut = .modifierOnly(only)
        } else {
            // Two+ modifiers held with no base key yet is ambiguous (not a
            // supported shortcut shape) — keep waiting rather than
            // committing something misleading.
            pendingShortcut = nil
        }
        restartCommitTimer()
    }

    private func restartCommitTimer() {
        commitTimer?.invalidate()
        commitTimer = Timer.scheduledTimer(withTimeInterval: Self.commitDelay, repeats: false) { [weak self] _ in
            self?.commitPendingShortcut()
        }
    }

    private func commitPendingShortcut() {
        commitTimer?.invalidate()
        commitTimer = nil
        guard let pendingShortcut else { return }
        onCapture?(pendingShortcut)
        self.pendingShortcut = nil
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    private func cancelRecording() {
        commitTimer?.invalidate()
        commitTimer = nil
        capturedModifiers = []
        capturedKeyCode = nil
        pendingShortcut = nil
        isRecording = false
    }

    /// NX_DEVICE*KEYMASK bits (IOLLEvent.h) — the device-dependent portion
    /// of NSEvent.modifierFlags.rawValue that distinguishes left/right.
    private static func deviceMask(for modifier: ModifierKey) -> UInt {
        switch modifier {
        case .leftControl: return 0x0000_0001
        case .rightControl: return 0x0000_2000
        case .leftShift: return 0x0000_0002
        case .rightShift: return 0x0000_0004
        case .leftCommand: return 0x0000_0008
        case .rightCommand: return 0x0000_0010
        case .leftOption: return 0x0000_0020
        case .rightOption: return 0x0000_0040
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        let backgroundColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.15)
            : NSColor(white: 0.5, alpha: 0.12)
        backgroundColor.setFill()
        backgroundPath.fill()

        if isRecording {
            NSColor.controlAccentColor.setStroke()
            backgroundPath.lineWidth = 1.5
            backgroundPath.stroke()
        }

        let text: String
        let color: NSColor
        if let pendingShortcut {
            text = pendingShortcut.displayString
            color = .controlAccentColor
        } else if isRecording {
            text = "按下按键…"
            color = .controlAccentColor
        } else if let displayShortcut {
            text = displayShortcut.displayString
            color = .labelColor
        } else {
            text = "点按录制"
            color = .secondaryLabelColor
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        text.draw(at: point, withAttributes: attributes)
    }
}
