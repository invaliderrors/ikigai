import AppKit
import IkigaiCore
import IkigaiRender

/// A borderless window at desktop level: below the desktop icons, above the system wallpaper,
/// on every Space, ignored by Mission Control and the mouse.
final class DesktopWindow: NSWindow {
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        hasShadow = false
        animationBehavior = .none
        backgroundColor = .black
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Shows the assigned wallpaper on every screen and plays it only while someone can see it.
@MainActor public final class DesktopController {
    public private(set) var screens: [ScreenInfo] = []
    /// Why each screen isn't playing; a screen absent from the map is playing (or has no wallpaper).
    public private(set) var intermissions: [String: Intermission] = [:]
    public var preferences = PausePreferences() { didSet { refresh() } }
    public var userPaused = false { didSet { refresh() } }
    public var onChange: (() -> Void)?

    private struct Stage {
        let window: DesktopWindow
        let wallpaperID: UUID
        let host: WallpaperHost
    }

    private var stages: [String: Stage] = [:]
    private var wallpaperFor: (ScreenInfo) -> InstalledWallpaper? = { _ in nil }
    private let monitor = SystemMonitor()
    private var tokens: [NSObjectProtocol] = []

    public init() {
        monitor.onChange = { [weak self] in self?.refresh() }
        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        })
        tokens.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil, queue: .main) { [weak self] note in
            let changed = (note.object as AnyObject?).map(ObjectIdentifier.init)  // Sendable, unlike the window
            MainActor.assumeIsolated {
                guard let self, self.stages.values.contains(where: { ObjectIdentifier($0.window) == changed }) else { return }
                self.refresh()
            }
        })
        // Switching Spaces can reveal or hide a full-screen app without changing our windows' occlusion,
        // and the window list lags the animation, so check again once it settles.
        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    self?.refresh()
                }
            }
        })
        screens = ScreenInfo.connected()
    }

    isolated deinit {
        tokens.forEach {
            NotificationCenter.default.removeObserver($0)
            NSWorkspace.shared.notificationCenter.removeObserver($0)
        }
        stages.values.forEach { $0.window.orderOut(nil) }
    }

    /// Sets what each screen should show and applies it. Kept and reapplied when screens change.
    public func show(_ wallpaperFor: @escaping (ScreenInfo) -> InstalledWallpaper?) {
        self.wallpaperFor = wallpaperFor
        sync()
    }

    private func sync() {
        screens = ScreenInfo.connected()
        var next: [String: Stage] = [:]
        for screen in screens {
            guard let wallpaper = wallpaperFor(screen) else { continue }
            if let stage = stages[screen.id], stage.wallpaperID == wallpaper.id {
                stage.window.setFrame(screen.frame, display: true)  // same wallpaper: keep playing, follow resolution changes
                next[screen.id] = stage
            } else if let host = makeHost(for: wallpaper) {
                let window = DesktopWindow(frame: screen.frame)
                host.view.frame = CGRect(origin: .zero, size: screen.frame.size)
                host.view.autoresizingMask = [.width, .height]
                window.contentView = host.view
                window.orderFront(nil)
                next[screen.id] = Stage(window: window, wallpaperID: wallpaper.id, host: host)
            }
        }
        for (id, stage) in stages where next[id]?.window !== stage.window {
            stage.host.setPlaying(false)
            stage.window.orderOut(nil)
        }
        stages = next
        refresh()
    }

    private func refresh() {
        var system = monitor.conditions
        system.userPaused = userPaused
        var result: [String: Intermission] = [:]
        for screen in screens {
            guard let stage = stages[screen.id] else { continue }
            let covered = !stage.window.occlusionState.contains(.visible)
            // Only look for a full-screen app when the desktop is hidden anyway; it's the rarer, costlier check.
            let conditions = ScreenConditions(covered: covered, fullScreen: covered && FullScreen.isCovering(screen.displayID))
            let intermission = PausePolicy.intermission(system: system, screen: conditions, preferences: preferences)
            stage.host.setPlaying(intermission == nil)
            result[screen.id] = intermission
        }
        intermissions = result
        onChange?()
    }
}
