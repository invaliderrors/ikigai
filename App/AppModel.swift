import Foundation
import IkigaiCore
import IkigaiDesktop
import IkigaiRender
import Observation

/// The app's single source of truth: the library on disk, what each screen shows, and the desktop.
@MainActor @Observable final class AppModel {
    static let shared = AppModel()

    private(set) var wallpapers: [InstalledWallpaper] = []
    /// Packages that failed validation; they stay on disk and the Library says how many.
    private(set) var skippedCount = 0
    private(set) var screens: [ScreenInfo] = []
    private(set) var intermissions: [String: Intermission] = [:]
    private(set) var importsInFlight = 0
    var alert: String?
    /// Bumped to ask for the Library window; the menu bar icon view opens it.
    var libraryRequests = 0

    private(set) var assignments: ScreenAssignments {
        didSet { Self.save(assignments, key: "screenAssignments") }
    }
    var preferences: PausePreferences {
        didSet {
            Self.save(preferences, key: "pausePreferences")
            desktop.preferences = preferences
        }
    }
    var userPaused = false {
        didSet { desktop.userPaused = userPaused }
    }

    @ObservationIgnored private let library = WallpaperLibrary.standard
    @ObservationIgnored private let desktop = DesktopController()

    private init() {
        assignments = Self.load(key: "screenAssignments") ?? ScreenAssignments()
        preferences = Self.load(key: "pausePreferences") ?? PausePreferences()
    }

    /// Called once the app has finished launching, so desktop windows can be ordered in.
    func start() {
        desktop.preferences = preferences
        desktop.onChange = { [weak self] in
            guard let self else { return }
            screens = desktop.screens
            intermissions = desktop.intermissions
        }
        reload()
        // A first launch shouldn't leave people hunting for a menu bar icon.
        if wallpapers.isEmpty { libraryRequests += 1 }
    }

    // MARK: Reading

    func wallpaper(id: UUID?) -> InstalledWallpaper? {
        id.flatMap { id in wallpapers.first { $0.id == id } }
    }

    func wallpaper(on screen: ScreenInfo) -> InstalledWallpaper? {
        wallpaper(id: assignments.wallpaper(forScreen: screen.id))
    }

    /// 1-based position in the strip, as shown on letter boards ("Screen 2").
    func number(of screen: ScreenInfo) -> Int {
        (screens.firstIndex(of: screen) ?? 0) + 1
    }

    func screensShowing(_ wallpaper: InstalledWallpaper) -> [ScreenInfo] {
        screens.filter { self.wallpaper(on: $0)?.id == wallpaper.id }
    }

    // MARK: Showing

    func showEverywhere(_ wallpaper: InstalledWallpaper) {
        assignments.showEverywhere(wallpaper.id)
        apply()
    }

    func show(_ wallpaper: InstalledWallpaper, on screen: ScreenInfo) {
        assignments.show(wallpaper.id, onScreen: screen.id)
        apply()
    }

    func clear(_ screen: ScreenInfo) {
        assignments.turnOff(screen: screen.id, connected: screens.map(\.id))
        apply()
    }

    private func apply() {
        desktop.show { [weak self] screen in self?.wallpaper(on: screen) }
    }

    // MARK: Library

    func reload() {
        let result = library.load()
        wallpapers = result.wallpapers
        skippedCount = result.skipped.count
        assignments.keep(only: Set(wallpapers.map(\.id)))
        apply()
    }

    /// Imports videos and web folders. Copying runs off the main thread; large videos take a while.
    func importItems(_ urls: [URL]) {
        for url in urls {
            importsInFlight += 1
            Task {
                defer { importsInFlight -= 1 }
                do {
                    let imported = try await Task.detached { [library] in
                        url.hasDirectoryPath ? try library.importWebFolder(at: url) : try library.importVideo(at: url)
                    }.value
                    try? await Thumbnailer.makePreview(for: imported)  // a missing preview only costs the still
                    reload()
                } catch {
                    alert = Self.message(for: error, item: url.lastPathComponent)
                }
            }
        }
    }

    func moveToTrash(_ wallpaper: InstalledWallpaper) {
        do {
            try library.trash(wallpaper)
            assignments.remove(wallpaper.id)
            reload()
        } catch {
            alert = "“\(wallpaper.manifest.title)” couldn't be moved to the Trash. \(error.localizedDescription)"
        }
    }

    // MARK: Helpers

    private static func message(for error: Error, item: String) -> String {
        switch error as? WallpaperLibrary.ImportError {
        case .tooLarge(_, let limit)?:
            "“\(item)” is larger than \(ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)), the most Ikigai imports."
        case .notAVideo?:
            "“\(item)” isn't a video Ikigai can play. Try an MP4 or MOV file."
        case .missingIndexHTML?:
            "“\(item)” has no index.html at its top level, so it can't be a web wallpaper."
        case .containsSymbolicLink(let link)?:
            "“\(item)” contains a link to another place (“\(link)”). Copy the real files into the folder and try again."
        case nil:
            "“\(item)” couldn't be imported. \(error.localizedDescription)"
        }
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
