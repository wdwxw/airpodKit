import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum KeyCodeNames {
    private static let special: [CGKeyCode: String] = [
        CGKeyCode(kVK_Return): "↩",
        CGKeyCode(kVK_Tab): "⇥",
        CGKeyCode(kVK_Space): "Space",
        CGKeyCode(kVK_Delete): "⌫",
        CGKeyCode(kVK_Escape): "⎋",
        CGKeyCode(kVK_LeftArrow): "←",
        CGKeyCode(kVK_RightArrow): "→",
        CGKeyCode(kVK_UpArrow): "↑",
        CGKeyCode(kVK_DownArrow): "↓",
        CGKeyCode(kVK_F1): "F1", CGKeyCode(kVK_F2): "F2", CGKeyCode(kVK_F3): "F3", CGKeyCode(kVK_F4): "F4",
        CGKeyCode(kVK_F5): "F5", CGKeyCode(kVK_F6): "F6", CGKeyCode(kVK_F7): "F7", CGKeyCode(kVK_F8): "F8",
        CGKeyCode(kVK_F9): "F9", CGKeyCode(kVK_F10): "F10", CGKeyCode(kVK_F11): "F11", CGKeyCode(kVK_F12): "F12",
    ]

    static func name(for keyCode: CGKeyCode) -> String {
        if let special = special[keyCode] { return special }
        if let ch = character(for: keyCode), !ch.isEmpty {
            return ch.uppercased()
        }
        return "Key\(keyCode)"
    }

    private static func character(for keyCode: CGKeyCode) -> String? {
        guard let sourceUnmanaged = TISCopyCurrentKeyboardLayoutInputSource() else { return nil }
        let source = sourceUnmanaged.takeRetainedValue()
        guard let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0

        let status: OSStatus = layoutData.withUnsafeBytes { rawBuffer -> OSStatus in
            guard let keyboardLayout = rawBuffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return errSecParam
            }
            return UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDown),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
