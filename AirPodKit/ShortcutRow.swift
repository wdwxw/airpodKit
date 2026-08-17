import SwiftUI

struct ShortcutRow: View {
    let button: RemoteButton
    let label: String
    @Binding var shortcut: Shortcut?

    var body: some View {
        HStack(spacing: 12) {
            RemoteButtonIconView(button: button)
            Text(label).font(.system(size: 13, weight: .semibold))
            Spacer()
            ShortcutRecorderField(shortcut: $shortcut)
                .frame(width: 140, height: 24)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
