import AppKit
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
    /// Bumped whenever a preview image is written, so images showing that wallpaper reload.
    private(set) var previewRevision = 0
    @ObservationIgnored private var previewAttempts: Set<UUID> = []

    private(set) var assignments: ScreenAssignments {
        // A preview isn't the user's choice yet, so it's never saved: quitting mid-preview keeps what they had.
        didSet { if assignmentsBeforePreview == nil { Self.save(assignments, key: "screenAssignments") } }
    }
    /// The wallpaper being tried on the desktop from Welcome, not yet kept.
    private(set) var previewing: UUID?
    @ObservationIgnored private var assignmentsBeforePreview: ScreenAssignments?
    private(set) var installingStarterPack = false
    var welcomeRequests = 0
    /// A scene to open in the Studio; the menu bar icon view opens it.
    var studioRequest: UUID?
    var preferences: PausePreferences {
        didSet {
            Self.save(preferences, key: "pausePreferences")
            desktop.preferences = preferences
        }
    }
    var userPaused = false {
        didSet { desktop.userPaused = userPaused }
    }

    @ObservationIgnored let library = WallpaperLibrary.standard
    @ObservationIgnored private var openWindows = 0
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
        #if DEBUG
        // Lets UI checks open a scene in the Studio without a click: IKIGAI_OPEN_STUDIO=<wallpaper id>.
        if let id = ProcessInfo.processInfo.environment["IKIGAI_OPEN_STUDIO"].flatMap(UUID.init) { studioRequest = id; return }
        #endif
        // A first launch shouldn't leave people hunting for a menu bar icon.
        if !UserDefaults.standard.bool(forKey: Self.welcomeSeenKey) {
            welcomeRequests += 1
            Task { await installStarterPack() }
        } else if wallpapers.isEmpty {
            libraryRequests += 1
        }
    }

    // MARK: Welcome and the starter pack

    static let starterPackTag = "Starter Pack"
    private static let welcomeSeenKey = "hasSeenWelcome"

    var starterWallpapers: [InstalledWallpaper] {
        wallpapers.filter { $0.manifest.tags.contains(Self.starterPackTag) }
    }

    /// Copies the bundled starter wallpapers into the library, skipping any already there.
    func installStarterPack() async {
        guard !installingStarterPack,
              let pack = Bundle.main.url(forResource: "StarterPack", withExtension: nil),
              let folders = try? FileManager.default.contentsOfDirectory(at: pack, includingPropertiesForKeys: nil)
        else { return }
        installingStarterPack = true
        defer { installingStarterPack = false }
        let installed = Set(starterWallpapers.map(\.manifest.title))
        let tag = Self.starterPackTag
        for folder in folders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where !installed.contains(folder.lastPathComponent) {
            do {
                try await Task.detached { [library] in
                    let wallpaper = try library.importFolder(at: folder)
                    try library.update(wallpaper, title: wallpaper.manifest.title, tags: [tag])
                }.value
            } catch {
                alert = "The starter wallpaper “\(folder.lastPathComponent)” couldn't be added. \(error.localizedDescription)"
            }
        }
        reload()
    }

    /// Shows a wallpaper everywhere without making it the user's choice yet.
    func preview(_ wallpaper: InstalledWallpaper) {
        if assignmentsBeforePreview == nil { assignmentsBeforePreview = assignments }
        assignments.showEverywhere(wallpaper.id)
        previewing = wallpaper.id
        apply()
    }

    func keepPreview() {
        assignmentsBeforePreview = nil
        previewing = nil
        Self.save(assignments, key: "screenAssignments")
        UserDefaults.standard.set(true, forKey: Self.welcomeSeenKey)
    }

    /// Puts back exactly what the desktop showed before the preview. Closing Welcome counts as seen.
    func endPreview() {
        if let before = assignmentsBeforePreview { assignments = before }
        assignmentsBeforePreview = nil
        previewing = nil
        apply()
        UserDefaults.standard.set(true, forKey: Self.welcomeSeenKey)
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
        makeMissingPreviews()
    }

    /// One at a time, once per wallpaper per launch: a page that can't be previewed isn't retried in a loop.
    private func makeMissingPreviews() {
        let missing = wallpapers.filter {
            !previewAttempts.contains($0.id)
                && !FileManager.default.fileExists(atPath: $0.previewURL.path)
        }
        guard !missing.isEmpty else { return }
        previewAttempts.formUnion(missing.map(\.id))
        Task {
            for wallpaper in missing {
                try? await Thumbnailer.makePreview(for: wallpaper)
                previewRevision += 1
            }
        }
    }

    /// Imports videos and web folders. Copying runs off the main thread; large videos take a while.
    func importItems(_ urls: [URL]) {
        for url in urls {
            importsInFlight += 1
            Task {
                defer { importsInFlight -= 1 }
                do {
                    _ = try await Task.detached { [library] in
                        // Ask the file system: a dropped folder's URL doesn't always end in a slash.
                        let isFolder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                        if isFolder { return try library.importFolder(at: url) }
                        if url.pathExtension.lowercased() == WallpaperLibrary.packageExtension { return try library.importArchive(at: url) }
                        return try library.importVideo(at: url)
                    }.value
                    reload()  // also makes its preview
                } catch {
                    alert = Self.message(for: error, item: url.lastPathComponent)
                }
            }
        }
    }

    /// Writes a shareable `.ikigai` file. Compressing a large video takes a moment, so it runs off the main thread.
    func export(_ wallpaper: InstalledWallpaper, to destination: URL) {
        Task {
            do {
                try await Task.detached { [library] in try library.export(wallpaper, to: destination) }.value
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch {
                alert = "“\(wallpaper.manifest.title)” couldn't be exported. \(error.localizedDescription)"
            }
        }
    }

    /// Every tag in the library with how many wallpapers carry it, A–Z (case-insensitive).
    var allTags: [(name: String, count: Int)] {
        var counts: [String: (name: String, count: Int)] = [:]
        for tag in wallpapers.flatMap(\.manifest.tags) {
            counts[tag.lowercased(), default: (tag, 0)].count += 1
        }
        return counts.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func update(_ wallpaper: InstalledWallpaper, title: String, tags: [String]) {
        guard title != wallpaper.manifest.title || tags != wallpaper.manifest.tags else { return }
        do {
            try library.update(wallpaper, title: title, tags: tags)
            reload()
        } catch {
            alert = "“\(wallpaper.manifest.title)” couldn't be changed. \(error.localizedDescription)"
        }
    }

    // MARK: Studio

    /// Starts a scene from a picture; returns its id so the Studio can open it.
    func createScene(from image: URL) async -> UUID? {
        do {
            let scene = try await Task.detached { [library] in try library.createScene(from: image) }.value
            reload()
            return scene.id
        } catch {
            alert = Self.message(for: error, item: image.lastPathComponent)
            return nil
        }
    }

    /// After the Studio saves: fresh preview, and screens showing the scene reload it.
    func sceneSaved(_ wallpaper: InstalledWallpaper) {
        try? FileManager.default.removeItem(at: wallpaper.previewURL)
        previewAttempts.remove(wallpaper.id)
        desktop.reload(wallpaper.id)
        reload()
    }

    // MARK: Windows

    /// A Dock icon and full menus while any window is open; menu bar only when none are.
    func windowOpened() {
        openWindows += 1
        NSApp.setActivationPolicy(.regular)
    }

    func windowClosed() {
        openWindows = max(0, openWindows - 1)
        if openWindows == 0 { NSApp.setActivationPolicy(.accessory) }
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

    static func message(for error: Error, item: String) -> String {
        switch error as? WallpaperLibrary.ImportError {
        case .tooLarge(_, let limit)?:
            "“\(item)” is larger than \(ByteCountFormatter.string(fromByteCount: limit, countStyle: .file)), the most Ikigai imports."
        case .notAVideo?:
            "“\(item)” isn't a video Ikigai can play. Try an MP4 or MOV file."
        case .notAnImage?:
            "“\(item)” isn't an image. Scenes are made from PNG, JPEG, HEIC or other picture files."
        case .missingIndexHTML?:
            "“\(item)” has no index.html at its top level, so it can't be a web wallpaper."
        case .containsSymbolicLink(let link)?:
            "“\(item)” contains a link to another place (“\(link)”). Copy the real files into the folder and try again."
        case .unreadableArchive?:
            "“\(item)” isn't an Ikigai wallpaper file, or it's damaged."
        case .unsafeArchiveEntry(let entry)?:
            "“\(item)” was refused because it contains “\(entry)”, which could reach outside the wallpaper or is too large."
        case .invalidPackage?:
            "“\(item)” is missing parts it needs to play. A scene needs a scene.json whose images are all inside the folder."
        case nil where error is WallpaperManifest.DecodingFailure:
            "“\(item)” was made with a newer version of Ikigai. Update Ikigai to open it."
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
