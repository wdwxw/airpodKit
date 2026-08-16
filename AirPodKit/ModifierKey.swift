import Carbon.HIToolbox
import CoreGraphics

/// A specific physical modifier key, left/right distinguished. macOS's
/// device-independent `NSEvent.ModifierFlags` (`.command`, `.shift`, ...)
/// collapse both sides into one bit, so telling them apart requires reading
/// the actual key code from a `flagsChanged` event instead.
enum ModifierKey: String, CaseIterable, Codable, Hashable {
    case leftControl, rightControl
    case leftOption, rightOption
    case leftShift, rightShift
    case leftCommand, rightCommand

    /// Matches a `flagsChanged` event's `keyCode` to the specific side that
    /// changed.
    init?(keyCode: UInt16) {
        switch Int(keyCode) {
        case kVK_Control: self = .leftControl
        case kVK_RightControl: self = .rightControl
        case kVK_Option: self = .leftOption
        case kVK_RightOption: self = .rightOption
        case kVK_Shift: self = .leftShift
        case kVK_RightShift: self = .rightShift
        case kVK_Command: self = .leftCommand
        case kVK_RightCommand: self = .rightCommand
        default: return nil
        }
    }

    /// The virtual key code for synthesizing this exact key on its own
    /// (used when the shortcut IS a single modifier, not combined with a
    /// base key).
    var virtualKeyCode: CGKeyCode {
        switch self {
        case .leftControl: return CGKeyCode(kVK_Control)
        case .rightControl: return CGKeyCode(kVK_RightControl)
        case .leftOption: return CGKeyCode(kVK_Option)
        case .rightOption: return CGKeyCode(kVK_RightOption)
        case .leftShift: return CGKeyCode(kVK_Shift)
        case .rightShift: return CGKeyCode(kVK_RightShift)
        case .leftCommand: return CGKeyCode(kVK_Command)
        case .rightCommand: return CGKeyCode(kVK_RightCommand)
        }
    }

    /// The device-independent flag to combine with a base key when this
    /// modifier is part of a combo (e.g. ⌘V) — CGEventFlags has no
    /// left/right-specific mask for combos, only for the raw device bits,
    /// which not all apps honor, so combos use the generic mask.
    var comboFlag: CGEventFlags {
        switch self {
        case .leftControl, .rightControl: return .maskControl
        case .leftOption, .rightOption: return .maskAlternate
        case .leftShift, .rightShift: return .maskShift
        case .leftCommand, .rightCommand: return .maskCommand
        }
    }

    /// Explicit left/right label, since the user needs to see which side
    /// was recorded, not just which modifier.
    var displayLabel: String {
        switch self {
        case .leftControl: return "左⌃"
        case .rightControl: return "右⌃"
        case .leftOption: return "左⌥"
        case .rightOption: return "右⌥"
        case .leftShift: return "左⇧"
        case .rightShift: return "右⇧"
        case .leftCommand: return "左⌘"
        case .rightCommand: return "右⌘"
        }
    }

    /// Stable display ordering, matching macOS convention ⌃⌥⇧⌘.
    static let displayOrder: [ModifierKey] = [
        .leftControl, .rightControl,
        .leftOption, .rightOption,
        .leftShift, .rightShift,
        .leftCommand, .rightCommand,
    ]
}
