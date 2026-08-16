import SwiftUI

@main
struct AirPodKitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        setbuf(stdout, nil)
        RemapEngine.start()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView()
        } label: {
            Image(systemName: "airpods")
        }
        .menuBarExtraStyle(.window)
    }
}
