// Milestone 0 diagnostic spike — throwaway, not part of the real app.
// Confirms how the wired AirPods remote's Volume Up / Volume Down / center
// button presses actually surface on this Mac before building the real
// remap engine.
//
// Build:  swiftc -o spike main.swift -framework ApplicationServices -framework IOKit
// Run:    ./spike
//
// First run will need Accessibility + Input Monitoring approval in
// System Settings for the "spike" binary (or the terminal that launches it).

import ApplicationServices
import Cocoa
import IOKit.hid

setbuf(stdout, nil) // unbuffered so redirected output shows up live

// MARK: - Permissions

func checkAccessibility(prompt: Bool) -> Bool {
    let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
    return AXIsProcessTrustedWithOptions(opts)
}

func checkInputMonitoring() -> String {
    let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
    switch access {
    case kIOHIDAccessTypeGranted: return "granted"
    case kIOHIDAccessTypeDenied: return "denied"
    case kIOHIDAccessTypeUnknown: return "unknown (will prompt)"
    default: return "unrecognized (\(access.rawValue))"
    }
}

print("=== AirPodKit diagnostic spike ===")
print("Accessibility trusted: \(checkAccessibility(prompt: true))")
print("Input Monitoring access: \(checkInputMonitoring())")
_ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

print("""

If either permission shows as not granted, open:
  System Settings > Privacy & Security > Accessibility
  System Settings > Privacy & Security > Input Monitoring
and enable the binary running this (likely "spike" or your terminal app),
then re-run.

""")

// MARK: - NX_SYSDEFINED decoding

// NX_KEYTYPE_* constants (from IOKit/hidsystem/ev_keymap.h)
let NX_KEYTYPE_SOUND_UP: Int32 = 0
let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
let NX_KEYTYPE_PLAY: Int32 = 16
let NX_SUBTYPE_AUX_CONTROL_BUTTONS: Int32 = 8

func describeKeyType(_ keyType: Int32) -> String {
    switch keyType {
    case NX_KEYTYPE_SOUND_UP: return "NX_KEYTYPE_SOUND_UP (volume up)"
    case NX_KEYTYPE_SOUND_DOWN: return "NX_KEYTYPE_SOUND_DOWN (volume down)"
    case NX_KEYTYPE_PLAY: return "NX_KEYTYPE_PLAY (play/pause, likely = center button)"
    default: return "unknown key type \(keyType)"
    }
}

// MARK: - Event tap

var consumeEvents = false // flip to true for phase 2 (swallow test)

func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    cgEvent: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type.rawValue == 14 { // NX_SYSDEFINED
        if let nsEvent = NSEvent(cgEvent: cgEvent), nsEvent.subtype.rawValue == NX_SUBTYPE_AUX_CONTROL_BUTTONS {
            let data1 = nsEvent.data1
            let keyType = Int32((data1 & 0xFFFF0000) >> 16)
            let keyStateByte = Int32((data1 & 0xFF00) >> 8)
            let isDown = keyStateByte == 0x0A
            let timestamp = Date()
            print("[\(timestamp)] subtype=\(nsEvent.subtype.rawValue) data1=0x\(String(data1, radix: 16)) keyType=\(describeKeyType(keyType)) state=\(isDown ? "DOWN" : "UP")")

            let isTargetKey = keyType == NX_KEYTYPE_SOUND_UP || keyType == NX_KEYTYPE_SOUND_DOWN || keyType == NX_KEYTYPE_PLAY
            if consumeEvents && isTargetKey {
                print("    -> consuming event (should block default system behavior)")
                return nil
            }
        }
    }
    return Unmanaged.passRetained(cgEvent)
}

let eventMask = (1 << 14) // NSEvent.EventTypeMask.systemDefined / NX_SYSDEFINED

guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: eventTapCallback,
    userInfo: nil
) else {
    print("FAILED to create event tap — check Accessibility/Input Monitoring permissions and re-run.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("""
Event tap installed. Listening in PASSIVE mode (not blocking anything yet).

>>> Press Volume Up, Volume Down, and the center button on your wired
>>> AirPods remote a few times each now. <<<

After you've confirmed the key types above look right, press Ctrl+C,
edit this file to set `consumeEvents = true`, rebuild, and re-run to
verify the tap can actually swallow the events (system volume/HUD
should stop responding to the three buttons while this runs).
""")

CFRunLoopRun()
