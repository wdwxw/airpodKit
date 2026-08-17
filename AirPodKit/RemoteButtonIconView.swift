import SwiftUI

struct RemoteButtonIconView: View {
    let button: RemoteButton

    private var symbolName: String {
        switch button {
        case .volumeUp: return "speaker.wave.3.fill"
        case .volumeDown: return "speaker.fill"
        case .center: return "record.circle"
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(.quaternary)
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            )
    }
}
