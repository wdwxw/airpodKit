import MediaPlayer

/// macOS falls back to auto-launching Music.app for a Play/Pause-type key
/// press when no app has claimed "Now Playing" status — and that fallback
/// happens through a system-level path our CGEventTap on NX_SYSDEFINED
/// never sees, so consuming the tap event alone can't stop it (confirmed:
/// the tap's own log showed both down and up correctly consumed while
/// Music still launched).
///
/// Registering a (no-op) MPRemoteCommandCenter handler and publishing
/// minimal MPNowPlayingInfoCenter info makes AirPodKit itself the
/// system's "Now Playing" target, so there's nothing left for macOS to
/// fall back to.
enum NowPlayingClaim {
    static func activate() {
        let commandCenter = MPRemoteCommandCenter.shared()
        let claimHandler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { _ in .success }

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.addTarget(handler: claimHandler)
        commandCenter.pauseCommand.addTarget(handler: claimHandler)
        commandCenter.togglePlayPauseCommand.addTarget(handler: claimHandler)

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "AirPodKit",
            MPNowPlayingInfoPropertyPlaybackRate: 0.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = .paused
    }
}
