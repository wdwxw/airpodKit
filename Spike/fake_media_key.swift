// Throwaway diagnostic: synthesize a real NX_SYSDEFINED Play/Pause key
// event (the same event type/subtype real wired-remote center-button
// presses generate) to test AirPodKit's consumption logic in isolation,
// without needing physical hardware.
//
// Build: swiftc -o fake_media_key fake_media_key.swift -framework AppKit
// Run:   ./fake_media_key

import AppKit

func postFakeMediaKey(keyType: Int32, down: Bool) {
    let state: Int32 = down ? 0x0A : 0x0B
    let data1 = (Int(keyType) << 16) | (Int(state) << 8)

    guard let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: 0,
        context: nil,
        subtype: 8, // NX_SUBTYPE_AUX_CONTROL_BUTTONS
        data1: data1,
        data2: -1
    ), let cgEvent = event.cgEvent else {
        print("failed to construct fake event")
        return
    }
    cgEvent.post(tap: .cghidEventTap)
}

let NX_KEYTYPE_PLAY: Int32 = 16

print("Posting fake center-button (Play/Pause) press...")
postFakeMediaKey(keyType: NX_KEYTYPE_PLAY, down: true)
usleep(50_000)
postFakeMediaKey(keyType: NX_KEYTYPE_PLAY, down: false)
print("Done.")
