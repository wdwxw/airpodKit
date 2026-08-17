import SwiftUI

@main
struct AirPodKitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        setbuf(stdout, nil)
        RemapEngine.start()
    }

    var body: some Scene {
        // The visible menu-bar entry is managed explicitly by AppDelegate.
        // Keeping only a settings scene prevents SwiftUI from creating a
        // second, implicit MenuBarExtra instance.
        Settings {
            EmptyView()
        }
    }
}
