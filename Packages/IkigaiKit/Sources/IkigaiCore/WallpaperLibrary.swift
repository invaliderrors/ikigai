import AppleArchive
import Foundation
import System
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
        case notAnImage(String)
        case missingIndexHTML
        case containsSymbolicLink(String)
        case unreadableArchive
        /// An entry that could escape the package or isn't a plain file or folder.
        case unsafeArchiveEntry(String)
        case invalidPackage
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
              entry.resolvingSymlinksInPath().path.hasPrefix(url.resolvingSymlinksInPath().path + "/"),
              // A scene must load cleanly: every layer and mask it names, inside the package.
              manifest.kind != .scene || (try? SceneDocument.load(entry: entry, package: url)) != nil
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

    // MARK: Sharing (.ikigai files)

    /// Type, path, data and permissions only: no owner ids or timestamps from the creator's Mac.
    /// Built per use: FieldKeySet isn't Sendable, so it can't be a shared static.
    private static var archiveKeys: ArchiveHeader.FieldKeySet { ArchiveHeader.FieldKeySet("TYP,PAT,DAT,MOD")! }

    /// Writes the package as one LZFSE-compressed Apple Archive, the shareable `.ikigai` file.
    public func export(_ wallpaper: InstalledWallpaper, to destination: URL) throws {
        guard let file = ArchiveByteStream.fileStream(path: FilePath(destination.path), mode: .writeOnly,
                                                      options: [.create, .truncate], permissions: [.ownerReadWrite, .groupRead, .otherRead]),
              let compressed = ArchiveByteStream.compressionStream(using: .lzfse, writingTo: file),
              let encoder = ArchiveStream.encodeStream(writingTo: compressed)
        else { throw CocoaError(.fileWriteUnknown) }
        do {
            try encoder.writeDirectoryContents(archiveFrom: FilePath(wallpaper.packageURL.path), keySet: Self.archiveKeys)
            // Closing flushes the compressor; a failure here means a truncated file, so it must throw.
            try encoder.close()
            try compressed.close()
            try file.close()
        } catch {
            try? encoder.close(); try? compressed.close(); try? file.close()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    /// Installs a shared `.ikigai` file. It comes from a stranger, so every entry is checked before it's
    /// written, and the wallpaper gets a fresh id so it can't overwrite or impersonate one already installed.
    public func importArchive(at source: URL) throws -> InstalledWallpaper {
        try checkSize(of: source)
        let staging = root.appending(path: ".import-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try extract(source, into: staging)
            try checkSize(of: staging)
            let manifestURL = staging.appending(path: Self.manifestName)
            guard let data = try? Data(contentsOf: manifestURL) else { throw ImportError.invalidPackage }
            var manifest = try WallpaperManifest.decode(from: data)
            manifest.id = UUID()
            try manifest.encoded().write(to: manifestURL, options: .atomic)
            let destination = packageURL(for: manifest.id)
            try FileManager.default.moveItem(at: staging, to: destination)
            guard let installed = Self.validated(packageAt: destination) else {
                try? FileManager.default.removeItem(at: destination)
                throw ImportError.invalidPackage
            }
            return installed
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }

    private func extract(_ source: URL, into staging: URL) throws {
        let limit = UInt64(importLimit)
        var total: UInt64 = 0
        var refused: String?
        // Runs before each entry is written. It belongs to the extract stream: a filter passed to
        // `process` never sees extractBegin. One thread, so the running total isn't shared.
        let filter: ArchiveHeader.EntryFilter = { message, path, data in
            guard message == .extractBegin else { return .ok }
            guard case .header(let header)? = data,
                  header.entryType == .regularFile || header.entryType == .directory,
                  !path.isAbsolute, !path.components.contains(where: { $0.kind == .parentDirectory })
            else { refused = path.string; return .cancel }
            if case .blob(_, let size, _)? = header.field(forKey: ArchiveHeader.FieldKey("DAT")) { total += size }
            if total > limit { refused = path.string; return .cancel }
            return .ok
        }
        guard let file = ArchiveByteStream.fileStream(path: FilePath(source.path), mode: .readOnly, options: [], permissions: []),
              let decompressed = ArchiveByteStream.decompressionStream(readingFrom: file),
              let decoder = ArchiveStream.decodeStream(readingFrom: decompressed),
              let extractor = ArchiveStream.extractStream(extractingTo: FilePath(staging.path), selectUsing: filter,
                                                          flags: [.ignoreOperationNotPermitted], threadCount: 1)
        else { throw ImportError.unreadableArchive }
        defer { try? extractor.close(); try? decoder.close(); try? decompressed.close(); try? file.close() }

        do {
            _ = try ArchiveStream.process(readingFrom: decoder, writingTo: extractor)
        } catch {
            throw refused.map(ImportError.unsafeArchiveEntry) ?? ImportError.unreadableArchive
        }
        if let refused { throw ImportError.unsafeArchiveEntry(refused) }
    }

    // MARK: Editing

    public static let maxTitleLength = 80
    public static let maxTags = 12
    public static let maxTagLength = 32

    /// Renames and retags a wallpaper by rewriting its manifest atomically. Titles are trimmed and
    /// capped; tags are trimmed, capped, and deduplicated ignoring case, keeping the first spelling.
    @discardableResult
    public func update(_ wallpaper: InstalledWallpaper, title: String, tags: [String]) throws -> InstalledWallpaper {
        var manifest = wallpaper.manifest
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        manifest.title = trimmed.isEmpty ? manifest.title : String(trimmed.prefix(Self.maxTitleLength))
        manifest.tags = Self.normalizedTags(tags)
        try manifest.encoded().write(to: wallpaper.packageURL.appending(path: Self.manifestName), options: .atomic)
        return InstalledWallpaper(manifest: manifest, packageURL: wallpaper.packageURL)
    }

    public static func normalizedTags(_ tags: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for tag in tags {
            let clean = String(tag.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxTagLength))
            guard !clean.isEmpty, seen.insert(clean.lowercased()).inserted else { continue }
            result.append(clean)
            if result.count == maxTags { break }
        }
        return result
    }

    /// A folder is a scene when it has a `scene.json`, otherwise a web wallpaper.
    public func importFolder(at folder: URL) throws -> InstalledWallpaper {
        FileManager.default.fileExists(atPath: folder.appending(path: "scene.json").path)
            ? try importSceneFolder(at: folder)
            : try importWebFolder(at: folder)
    }

    /// A scene is a folder with a `scene.json` and the images it names; everything in it is copied.
    public func importSceneFolder(at folder: URL) throws -> InstalledWallpaper {
        guard FileManager.default.fileExists(atPath: folder.appending(path: "scene.json").path) else {
            throw ImportError.invalidPackage
        }
        try checkSize(of: folder)
        let installed = try install(title: folder.lastPathComponent, kind: .scene, entry: "assets/scene.json") { assets in
            for item in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                try FileManager.default.copyItem(at: item, to: assets.appending(path: item.lastPathComponent))
            }
        }
        guard Self.validated(packageAt: installed.packageURL) != nil else {
            try? FileManager.default.removeItem(at: installed.packageURL)
            throw ImportError.invalidPackage
        }
        return installed
    }

    // MARK: Creating scenes (the Studio)

    public static let creationsTag = "My Creations"

    /// A new scene with one layer: the picture the creator started from.
    public func createScene(from image: URL) throws -> InstalledWallpaper {
        try checkImage(image)
        let scene = SceneDocument(layers: [SceneDocument.Layer(image: image.lastPathComponent)])
        let installed = try install(title: image.deletingPathExtension().lastPathComponent, kind: .scene,
                                    entry: "assets/scene.json") { assets in
            try FileManager.default.copyItem(at: image, to: assets.appending(path: image.lastPathComponent))
            try Self.encode(scene).write(to: assets.appending(path: "scene.json"), options: .atomic)
        }
        return try update(installed, title: installed.manifest.title, tags: [Self.creationsTag])
    }

    /// Copies an image into a scene's folder and returns the name to use in scene.json.
    public func addImage(_ image: URL, to wallpaper: InstalledWallpaper) throws -> String {
        try checkImage(image)
        let folder = wallpaper.entryURL.deletingLastPathComponent()
        let stem = image.deletingPathExtension().lastPathComponent, ext = image.pathExtension
        var name = image.lastPathComponent, n = 1
        while FileManager.default.fileExists(atPath: folder.appending(path: name).path) {
            n += 1
            name = "\(stem)-\(n).\(ext)"
        }
        try FileManager.default.copyItem(at: image, to: folder.appending(path: name))
        return name
    }

    /// Saves an edited scene. It's written beside the old file and validated first, so an edit that
    /// names a missing image can never replace a working scene.
    public func saveScene(_ scene: SceneDocument, to wallpaper: InstalledWallpaper) throws {
        var scene = scene
        scene.version = SceneDocument.currentVersion
        let entry = wallpaper.entryURL
        let draft = entry.deletingLastPathComponent().appending(path: ".scene-draft.json")
        defer { try? FileManager.default.removeItem(at: draft) }
        try Self.encode(scene).write(to: draft, options: .atomic)
        _ = try SceneDocument.load(entry: draft, package: wallpaper.packageURL)
        _ = try FileManager.default.replaceItemAt(entry, withItemAt: draft)
    }

    public func scene(of wallpaper: InstalledWallpaper) throws -> SceneDocument {
        try JSONDecoder().decode(SceneDocument.self, from: Data(contentsOf: wallpaper.entryURL))
    }

    private static func encode(_ scene: SceneDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(scene)
    }

    private func checkImage(_ url: URL) throws {
        guard let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) else {
            throw ImportError.notAnImage(url.lastPathComponent)
        }
        try checkSize(of: url)
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
