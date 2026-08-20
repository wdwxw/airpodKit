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
        // This empty scene supplies the SwiftUI App lifecycle without adding
        // another visible window or menu-bar entry.
        Settings {
            EmptyView()
        }
    }
}
