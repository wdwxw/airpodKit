import Combine
import Foundation

struct ButtonMappings: Codable {
    var volumeUp: Shortcut?
    var center: Shortcut?
    var volumeDown: Shortcut?
}

final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()

    @Published var mappings: ButtonMappings {
        didSet { persist() }
    }

    private let defaultsKey = "com.airpodkit.buttonMappings"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode(ButtonMappings.self, from: data) {
            mappings = decoded
        } else {
            mappings = ButtonMappings()
        }
    }

    func shortcut(for button: RemoteButton) -> Shortcut? {
        switch button {
        case .volumeUp: return mappings.volumeUp
        case .center: return mappings.center
        case .volumeDown: return mappings.volumeDown
        }
    }

    func setShortcut(_ shortcut: Shortcut?, for button: RemoteButton) {
        switch button {
        case .volumeUp: mappings.volumeUp = shortcut
        case .center: mappings.center = shortcut
        case .volumeDown: mappings.volumeDown = shortcut
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
