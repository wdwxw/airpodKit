import SwiftUI

struct PopoverRootView: View {
    @ObservedObject private var store = ShortcutStore.shared
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var launchAtLogin = LaunchAtLoginManager.shared

    private static let iconGradient = LinearGradient(
        colors: [Color(red: 0.35, green: 0.62, blue: 0.98), Color(red: 0.20, green: 0.40, blue: 0.90)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)

            VStack(alignment: .leading, spacing: 14) {
                header

                if !permissions.allGranted {
                    PermissionsOnboardingView(permissions: permissions)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.orange.opacity(0.08))
                        )
                }

                shortcutsPanel
                buttonDetectionRow
                footer
            }
            .padding(16)
        }
        .frame(width: 340)
        .onAppear {
            permissions.refresh()
            launchAtLogin.refresh()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Self.iconGradient)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "airpods")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("AirPodKit").font(.system(size: 16, weight: .bold))
                Text("把耳机线控变成快捷键")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            statusPill
        }
    }

    private var statusPill: some View {
        let listening = permissions.allGranted
        let tint = listening ? Color.green : Color.orange
        return HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(listening ? "正在监听" : "未监听")
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.15)))
    }

    private var shortcutsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("按键映射")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ShortcutRow(button: .volumeUp, label: "音量 +", shortcut: bindingFor(.volumeUp))
            Divider().padding(.leading, 56)
            ShortcutRow(button: .center, label: "中间键", shortcut: bindingFor(.center))
            Divider().padding(.leading, 56)
            ShortcutRow(button: .volumeDown, label: "音量 −", shortcut: bindingFor(.volumeDown))
                .padding(.bottom, 4)
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var buttonDetectionRow: some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([DebugLog.fileURL])
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "waveform.badge.mic")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("按钮检测").font(.system(size: 13, weight: .semibold))
                    Text("遇到问题时展开查看原始事件")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.regularMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            )) {
                Text("登录时自动启动").font(.system(size: 12))
            }
            .toggleStyle(.checkbox)

            Spacer()

            Text(appVersionString)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                (NSApp.delegate as? AppDelegate)?.requestTerminationFromMenu()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("退出")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(version)"
    }

    private func bindingFor(_ button: RemoteButton) -> Binding<Shortcut?> {
        Binding(
            get: { store.shortcut(for: button) },
            set: { store.setShortcut($0, for: button) }
        )
    }
}
