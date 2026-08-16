import SwiftUI

struct PopoverRootView: View {
    @ObservedObject private var store = ShortcutStore.shared
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !permissions.allGranted {
                PermissionsOnboardingView(permissions: permissions)
                Divider()
            }

            Text("按键映射")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ShortcutRow(button: .volumeUp, label: "音量加", shortcut: bindingFor(.volumeUp))
            ShortcutRow(button: .center, label: "中间键", shortcut: bindingFor(.center))
            ShortcutRow(button: .volumeDown, label: "音量减", shortcut: bindingFor(.volumeDown))

            Divider().padding(.vertical, 6)

            HStack {
                Text("开机时启动").font(.system(size: 12.5))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)

            Divider().padding(.vertical, 6)

            Button("退出 AirPodKit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
        }
        .frame(width: 300)
        .onAppear {
            permissions.refresh()
            launchAtLogin.refresh()
        }
    }

    private func bindingFor(_ button: RemoteButton) -> Binding<Shortcut?> {
        Binding(
            get: { store.shortcut(for: button) },
            set: { store.setShortcut($0, for: button) }
        )
    }
}
