import AppKit
import AVFoundation

/// A muted, looping, aspect-filled movie.
@MainActor public final class VideoHost: WallpaperHost {
    public let view: NSView
    private let player = AVQueuePlayer()
    private let looper: AVPlayerLooper

    public init(url: URL) {
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false  // a wallpaper must never keep the Mac awake
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        view = NSView()
        view.layer = layer
        view.wantsLayer = true
    }

    public func setPlaying(_ playing: Bool) {
        playing ? player.play() : player.pause()
    }
}
