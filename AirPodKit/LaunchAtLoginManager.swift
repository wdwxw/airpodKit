import Foundation
import ServiceManagement

final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool

    private var isApplyingExternalChange = false

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        let current = SMAppService.mainApp.status == .enabled
        guard current != isEnabled else { return }
        isApplyingExternalChange = true
        isEnabled = current
        isApplyingExternalChange = false
    }

    func setEnabled(_ enabled: Bool) {
        guard !isApplyingExternalChange else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
        } catch {
            print("LaunchAtLoginManager: failed to \(enabled ? "register" : "unregister") — \(error)")
            refresh()
        }
    }
}
