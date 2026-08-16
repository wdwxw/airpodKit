import CoreGraphics
import Foundation

enum Shortcut: Codable, Equatable {
    /// A single modifier key by itself (e.g. just tapping right ⌥).
    case modifierOnly(ModifierKey)
    /// A base key plus zero or more modifiers (e.g. ⌘⇧S, or Return alone).
    case combo(modifiers: Set<ModifierKey>, keyCode: CGKeyCode)

    var displayString: String {
        switch self {
        case .modifierOnly(let modifier):
            return modifier.displayLabel
        case .combo(let modifiers, let keyCode):
            let modsString = ModifierKey.displayOrder
                .filter { modifiers.contains($0) }
                .map(\.displayLabel)
                .joined(separator: "")
            return modsString + KeyCodeNames.name(for: keyCode)
        }
    }
}
