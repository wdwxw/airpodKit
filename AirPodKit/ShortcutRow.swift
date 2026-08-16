import SwiftUI

struct ShortcutRow: View {
    let button: RemoteButton
    let label: String
    @Binding var shortcut: Shortcut?

    var body: some View {
        HStack(spacing: 10) {
            RemoteButtonIconView(button: button)
            Text(label).font(.system(size: 12.5))
            Spacer()
            ShortcutRecorderField(shortcut: $shortcut)
                .frame(width: 140, height: 22)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}
