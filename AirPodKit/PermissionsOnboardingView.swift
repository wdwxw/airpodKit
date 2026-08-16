import SwiftUI

struct PermissionsOnboardingView: View {
    @ObservedObject var permissions: PermissionsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("需要系统权限")
                .font(.system(size: 12.5, weight: .bold))
            Text("AirPodKit 需要「辅助功能」和「输入监控」权限才能捕获耳机遥控按键。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            permissionRow(title: "辅助功能", granted: permissions.accessibilityGranted) {
                permissions.requestAccessibility()
                permissions.openAccessibilitySettings()
            }
            permissionRow(title: "输入监控", granted: permissions.inputMonitoringGranted) {
                permissions.requestInputMonitoring()
                permissions.openInputMonitoringSettings()
            }
        }
        .padding(14)
    }

    @ViewBuilder
    private func permissionRow(title: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(title).font(.system(size: 12))
            Spacer()
            if !granted {
                Button("授权", action: action)
                    .font(.system(size: 11))
            }
        }
    }
}
