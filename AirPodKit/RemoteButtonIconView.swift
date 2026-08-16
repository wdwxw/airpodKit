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
        Image(systemName: symbolName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
    }
}
