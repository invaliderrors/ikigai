import AppKit
import IkigaiCore

/// Plays one wallpaper in a view. The desktop owns one host per screen.
@MainActor public protocol WallpaperHost: AnyObject {
    var view: NSView { get }
    func setPlaying(_ playing: Bool)
}

/// The host for a wallpaper's kind, or nil when this build can't play it yet (scenes arrive in Phase 2).
@MainActor public func makeHost(for wallpaper: InstalledWallpaper) -> WallpaperHost? {
    switch wallpaper.manifest.kind {
    case .video: VideoHost(url: wallpaper.entryURL)
    case .web: WebHost(page: wallpaper.entryURL, package: wallpaper.packageURL)
    case .scene: nil
    }
}
