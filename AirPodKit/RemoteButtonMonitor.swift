import AppKit
import ApplicationServices

enum RemoteButton: String, CaseIterable, Codable {
    case volumeUp
    case center
    case volumeDown
}

/// Captures wired remote button presses (Volume Up / Volume Down / center)
/// via a CGEventTap on NX_SYSDEFINED events — the same private event stream
/// macOS uses for keyboard media keys. See Milestone 0 in the project plan
/// for how this mechanism was confirmed.
final class RemoteButtonMonitor {
    static let shared = RemoteButtonMonitor()

    /// Called for both the down and up half of a press, `isDown` telling
    /// which. Return true to consume (block) that event; false to let the
    /// system's default behavior (volume change / play-pause) happen. Both
    /// halves must be consumed together when mapped — the system can act
    /// on either one, so swallowing only the down event still lets the up
    /// event trigger the original action.
    var onButtonPress: ((RemoteButton, _ isDown: Bool) -> Bool)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?

    private let NX_KEYTYPE_SOUND_UP: Int32 = 0
    private let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
    private let NX_KEYTYPE_PLAY: Int32 = 16
    private let NX_SUBTYPE_AUX_CONTROL_BUTTONS: Int32 = 8

    private init() {}

    /// Safe to call repeatedly (e.g. every time permissions change to
    /// granted): no-ops if a live tap already exists, and rebuilds if the
    /// previous tap died (permission revoked, or disabled by the system).
    func start() {
        if let tap = eventTap {
            if CGEvent.tapIsEnabled(tap: tap) { return }
            stop()
        }

        let mask = CGEventMask(1 << 14) // NX_SYSDEFINED
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<RemoteButtonMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            print("RemoteButtonMonitor: failed to create event tap — check Accessibility/Input Monitoring permission.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkTapHealth()
        }
        RunLoop.main.add(timer, forMode: .common)
        healthCheckTimer = timer
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        eventTap = nil
        runLoopSource = nil
    }

    private func checkTapHealth() {
        guard let tap = eventTap, !CGEvent.tapIsEnabled(tap: tap) else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14 else { return Unmanaged.passUnretained(event) }
        guard let nsEvent = NSEvent(cgEvent: event),
              Int32(nsEvent.subtype.rawValue) == NX_SUBTYPE_AUX_CONTROL_BUTTONS else {
            return Unmanaged.passUnretained(event)
        }

        let data1 = nsEvent.data1
        let keyType = Int32((data1 & 0xFFFF0000) >> 16)
        let keyStateByte = Int32((data1 & 0xFF00) >> 8)
        let isDown = keyStateByte == 0x0A
        guard keyStateByte == 0x0A || keyStateByte == 0x0B else {
            return Unmanaged.passUnretained(event)
        }

        let button: RemoteButton?
        switch keyType {
        case NX_KEYTYPE_SOUND_UP: button = .volumeUp
        case NX_KEYTYPE_SOUND_DOWN: button = .volumeDown
        case NX_KEYTYPE_PLAY: button = .center
        default: button = nil
        }

        if let button {
            DebugLog.log("saw NX_SYSDEFINED keyType=\(keyType) button=\(button) isDown=\(isDown)")
        }

        guard let button, let onButtonPress, onButtonPress(button, isDown) else {
            if let button {
                DebugLog.log("  -> not consumed (no mapping or no handler) for \(button)")
            }
            return Unmanaged.passUnretained(event)
        }
        DebugLog.log("  -> consumed for \(button)")
        return nil
    }
}
