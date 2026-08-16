import CoreGraphics

enum KeystrokeSynthesizer {
    static func post(_ shortcut: Shortcut) {
        switch shortcut {
        case .modifierOnly(let modifier):
            postKey(modifier.virtualKeyCode, flags: [])
        case .combo(let modifiers, let keyCode):
            var flags: CGEventFlags = []
            for modifier in modifiers { flags.insert(modifier.comboFlag) }
            postKey(keyCode, flags: flags)
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
