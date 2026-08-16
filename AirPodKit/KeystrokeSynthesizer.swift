import CoreGraphics

enum KeystrokeSynthesizer {
    static func post(_ shortcut: Shortcut) {
        switch shortcut {
        case .modifierOnly(let modifier):
            // A modifier key's own press/release is reported as
            // flagsChanged, not keyDown/keyUp — the *only* signal of
            // "which modifier, held or released" is the `flags` field
            // itself, so the down and up events need different flags
            // (down: this modifier set; up: none), unlike a combo's base
            // key where both events just report the modifiers held
            // throughout.
            postKey(modifier.virtualKeyCode, downFlags: [modifier.comboFlag], upFlags: [])
        case .combo(let modifiers, let keyCode):
            var flags: CGEventFlags = []
            for modifier in modifiers { flags.insert(modifier.comboFlag) }
            postKey(keyCode, downFlags: flags, upFlags: flags)
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, downFlags: CGEventFlags, upFlags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = downFlags
        up.flags = upFlags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
