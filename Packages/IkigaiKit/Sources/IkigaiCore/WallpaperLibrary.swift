import Foundation
import UniformTypeIdentifiers

/// A wallpaper package that loaded and validated.
public struct InstalledWallpaper: Identifiable, Hashable, Sendable {
    public let manifest: WallpaperManifest
    public let packageURL: URL

    public var id: UUID { manifest.id }
    /// The main file. Validated at load time, so it exists inside the package.
    public var entryURL: URL { PackagePath.resolve(manifest.entry, in: packageURL)! }
    public var previewURL: URL { packageURL.appending(path: WallpaperLibrary.previewName) }
}

/// The user's wallpapers on disk: one `<id>.ikigai` package folder each.
public struct WallpaperLibrary: Sendable {
    public static let manifestName = "manifest.json"
    public static let previewName = "preview.jpg"
    public static let packageExtension = "ikigai"

    public enum ImportError: Error, Equatable {
        case tooLarge(bytes: Int64, limit: Int64)
        case notAVideo(String)
        case missingIndexHTML
        case containsSymbolicLink(String)
    }

    public struct LoadResult: Sendable {
        public var wallpapers: [InstalledWallpaper]
        /// Packages that failed validation; they stay on disk untouched.
        public var skipped: [URL]
    }

    public let root: URL
    public let importLimit: Int64

    public init(root: URL, importLimit: Int64 = 4 * 1024 * 1024 * 1024) {
        self.root = root
        self.importLimit = importLimit
    }

    public static var standard: WallpaperLibrary {
        WallpaperLibrary(root: .applicationSupportDirectory.appending(path: "Ikigai/Library", directoryHint: .isDirectory))
    }

    public func packageURL(for id: UUID) -> URL {
        root.appending(path: "\(id.uuidString).\(Self.packageExtension)", directoryHint: .isDirectory)
    }

    // MARK: Loading

    public func load() -> LoadResult {
        let urls = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        var result = LoadResult(wallpapers: [], skipped: [])
        for url in urls where url.pathExtension == Self.packageExtension {
            // Rebuilt from the id so every package URL is spelled one way (the listing may say /private/var).
            if let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
               let wallpaper = Self.validated(packageAt: packageURL(for: id)) {
                result.wallpapers.append(wallpaper)
            } else {
                result.skipped.append(url)
            }
        }
        result.wallpapers.sort { $0.manifest.title.localizedStandardCompare($1.manifest.title) == .orderedAscending }
        return result
    }

    /// Packages come from strangers: the folder name must match the manifest id, the
    /// format must be one this build understands, and the entry must exist inside the package.
    static func validated(packageAt url: URL) -> InstalledWallpaper? {
        guard let data = try? Data(contentsOf: url.appending(path: manifestName)),
              let manifest = try? WallpaperManifest.decode(from: data),
              url.deletingPathExtension().lastPathComponent == manifest.id.uuidString,
              let entry = PackagePath.resolve(manifest.entry, in: url),
              FileManager.default.fileExists(atPath: entry.path),
              // PackagePath checks the text of the path; a symlink inside the package could still lead out.
              entry.resolvingSymlinksInPath().path.hasPrefix(url.resolvingSymlinksInPath().path + "/")
        else { return nil }
        return InstalledWallpaper(manifest: manifest, packageURL: url)
    }

    // MARK: Importing

    public func importVideo(at source: URL) throws -> InstalledWallpaper {
        guard let type = UTType(filenameExtension: source.pathExtension), type.conforms(to: .movie) else {
            throw ImportError.notAVideo(source.lastPathComponent)
        }
        try checkSize(of: source)
        return try install(title: source.deletingPathExtension().lastPathComponent, kind: .video,
                           entry: "assets/\(source.lastPathComponent)") { assets in
            try FileManager.default.copyItem(at: source, to: assets.appending(path: source.lastPathComponent))
        }
    }

    /// A web wallpaper is a folder with an `index.html`; everything in it is copied.
    public func importWebFolder(at folder: URL) throws -> InstalledWallpaper {
        guard FileManager.default.fileExists(atPath: folder.appending(path: "index.html").path) else {
            throw ImportError.missingIndexHTML
        }
        try checkSize(of: folder)
        return try install(title: folder.lastPathComponent, kind: .web, entry: "assets/index.html") { assets in
            for item in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                try FileManager.default.copyItem(at: item, to: assets.appending(path: item.lastPathComponent))
            }
        }
    }

    public func trash(_ wallpaper: InstalledWallpaper) throws {
        try FileManager.default.trashItem(at: wallpaper.packageURL, resultingItemURL: nil)
    }

    /// Builds the package in a hidden staging folder and moves it into place in one step,
    /// so a failed import never leaves a half-written package in the library.
    private func install(title: String, kind: WallpaperManifest.Kind, entry: String,
                         copyAssets: (URL) throws -> Void) throws -> InstalledWallpaper {
        let manifest = WallpaperManifest(title: title, kind: kind, entry: entry)
        let staging = root.appending(path: ".import-\(manifest.id.uuidString)", directoryHint: .isDirectory)
        let assets = staging.appending(path: "assets", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
            try copyAssets(assets)
            try manifest.encoded().write(to: staging.appending(path: Self.manifestName), options: .atomic)
            let destination = packageURL(for: manifest.id)
            try FileManager.default.moveItem(at: staging, to: destination)
            return InstalledWallpaper(manifest: manifest, packageURL: destination)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }

    /// Enforces the size cap and refuses symbolic links, which could point outside the package.
    private func checkSize(of url: URL) throws {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        func size(_ url: URL) throws -> Int64 {
            let values = try url.resourceValues(forKeys: keys)
            if values.isSymbolicLink == true { throw ImportError.containsSymbolicLink(url.lastPathComponent) }
            // The larger of the two: a sparse file's allocated size understates what copying it writes.
            return Int64(max(values.totalFileAllocatedSize ?? 0, values.fileSize ?? 0))
        }
        var total = try size(url)
        if let items = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) {
            for case let item as URL in items {
                total += try size(item)
                if total > importLimit { break }
            }
        }
        if total > importLimit { throw ImportError.tooLarge(bytes: total, limit: importLimit) }
    }
}
