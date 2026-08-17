import Foundation

/// Minimal file logger so button-press behavior can be inspected after the
/// fact, regardless of how the app was launched (no terminal attached when
/// launched via `open` / login item / Dock). Appends timestamped lines to
/// ~/Library/Logs/AirPodKit/airpodkit.log.
enum DebugLog {
    /// Exposed so the popover's "按钮检测" row can reveal the same file in
    /// Finder — the log itself is still only ever written on `writeQueue`.
    static let fileURL: URL = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/AirPodKit/airpodkit.log")

    /// Never do filesystem I/O on the CGEventTap callback path. A slow write
    /// can make WindowServer disable the tap for timing out, which would let
    /// the original media event reach macOS.
    private static let writeQueue = DispatchQueue(label: "com.airpodkit.debug-log")

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ message: String) {
        let timestamp = Date()
        writeQueue.async {
            let directory = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let line = "[\(formatter.string(from: timestamp))] \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }
}
