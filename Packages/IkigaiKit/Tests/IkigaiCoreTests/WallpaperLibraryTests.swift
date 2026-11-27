import Foundation
import Testing
@testable import IkigaiCore

struct WallpaperLibraryTests {
    let sandbox = FileManager.default.temporaryDirectory.appending(path: "ikigai-tests-\(UUID().uuidString)")
    var library: WallpaperLibrary { WallpaperLibrary(root: sandbox.appending(path: "Library"), importLimit: 1_000_000) }

    func file(_ name: String, bytes: Int = 16) throws -> URL {
        let url = sandbox.appending(path: "src/\(name)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
        return url
    }

    @Test func importedVideoLoadsBack() throws {
        let video = try library.importVideo(at: try file("Ocean Swell.mp4"))
        #expect(video.manifest.kind == .video)
        #expect(video.manifest.title == "Ocean Swell")
        #expect(FileManager.default.fileExists(atPath: video.entryURL.path))
        #expect(library.load().wallpapers == [video])
    }

    @Test func nonVideoIsRefused() throws {
        #expect(throws: WallpaperLibrary.ImportError.notAVideo("notes.txt")) {
            try library.importVideo(at: try file("notes.txt"))
        }
    }

    @Test func oversizedImportLeavesNothingBehind() throws {
        #expect(throws: WallpaperLibrary.ImportError.self) {
            try library.importVideo(at: try file("huge.mov", bytes: 2_000_000))
        }
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: library.root.path)) ?? []
        #expect(leftovers.isEmpty)
    }

    @Test func webFolderNeedsIndexHTML() throws {
        let folder = try file("site/style.css").deletingLastPathComponent()
        #expect(throws: WallpaperLibrary.ImportError.missingIndexHTML) { try library.importWebFolder(at: folder) }

        _ = try file("site/index.html")
        let web = try library.importWebFolder(at: folder)
        #expect(web.entryURL.lastPathComponent == "index.html")
        #expect(FileManager.default.fileExists(atPath: web.entryURL.deletingLastPathComponent().appending(path: "style.css").path))
    }

    @Test func webFolderWithSymlinkIsRefused() throws {
        let folder = try file("linked/index.html").deletingLastPathComponent()
        try FileManager.default.createSymbolicLink(at: folder.appending(path: "secrets"), withDestinationURL: URL(filePath: "/etc"))
        #expect(throws: WallpaperLibrary.ImportError.containsSymbolicLink("secrets")) { try library.importWebFolder(at: folder) }
    }

    // MARK: .ikigai files

    func shared(_ wallpaper: InstalledWallpaper) throws -> URL {
        let url = sandbox.appending(path: "shared/\(wallpaper.manifest.title).ikigai")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try library.export(wallpaper, to: url)
        return url
    }

    @Test func exportedWallpaperImportsAsANewCopy() throws {
        let original = try library.importVideo(at: try file("Ocean Swell.mov", bytes: 4096))
        let copy = try library.importArchive(at: try shared(original))
        #expect(copy.id != original.id)
        #expect(copy.manifest.title == "Ocean Swell")
        #expect(copy.manifest.entry == original.manifest.entry)
        #expect(try Data(contentsOf: copy.entryURL) == Data(contentsOf: original.entryURL))
        #expect(Set(library.load().wallpapers.map(\.id)) == [original.id, copy.id])
    }

    @Test func archiveFromANewerIkigaiIsRefused() throws {
        let original = try library.importVideo(at: try file("future.mov"))
        var manifest = original.manifest
        manifest.formatVersion = WallpaperManifest.currentFormatVersion + 1
        try manifest.encoded().write(to: original.packageURL.appending(path: WallpaperLibrary.manifestName))
        #expect(throws: WallpaperManifest.DecodingFailure.self) { try library.importArchive(at: try shared(original)) }
    }

    @Test func archiveWithASymlinkIsRefusedAndLeavesNothing() throws {
        let original = try library.importVideo(at: try file("linked.mov"))
        try FileManager.default.createSymbolicLink(at: original.packageURL.appending(path: "assets/escape"),
                                                   withDestinationURL: URL(filePath: "/etc/passwd"))
        let archive = try shared(original)
        try library.trash(original)
        #expect(throws: WallpaperLibrary.ImportError.unsafeArchiveEntry("assets/escape")) { try library.importArchive(at: archive) }
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: library.root.path)) ?? []
        #expect(leftovers.isEmpty)
    }

    @Test func archiveThatExpandsPastTheCapIsRefused() throws {
        // 2 MB of zeros compresses to almost nothing, so only the running total during extraction catches it.
        let roomy = WallpaperLibrary(root: library.root, importLimit: 10_000_000)
        let big = try roomy.importVideo(at: try file("zeros.mov", bytes: 2_000_000))
        let archive = try shared(big)
        try roomy.trash(big)
        let archiveSize = try FileManager.default.attributesOfItem(atPath: archive.path)[.size] as? Int ?? .max
        #expect(archiveSize < 1_000_000)
        #expect(throws: WallpaperLibrary.ImportError.unsafeArchiveEntry("assets/zeros.mov")) { try library.importArchive(at: archive) }
    }

    @Test func garbageIsNotAnArchive() throws {
        #expect(throws: WallpaperLibrary.ImportError.unreadableArchive) { try library.importArchive(at: try file("noise.ikigai", bytes: 512)) }
    }

    @Test func entryLinkingOutOfThePackageIsSkipped() throws {
        let video = try library.importVideo(at: try file("clip.mov"))
        try FileManager.default.removeItem(at: video.entryURL)
        try FileManager.default.createSymbolicLink(at: video.entryURL, withDestinationURL: try file("outside.mov"))
        #expect(library.load().wallpapers.isEmpty)
    }

    @Test func invalidPackagesAreSkippedNotDeleted() throws {
        let good = try library.importVideo(at: try file("good.mov"))
        // A package whose folder name doesn't match its manifest id.
        let renamed = library.root.appending(path: "\(UUID().uuidString).ikigai")
        try FileManager.default.copyItem(at: good.packageURL, to: renamed)
        // A package whose entry escapes the package.
        var escaping = WallpaperManifest(title: "Escape", kind: .video, entry: "../../etc/passwd")
        escaping.formatVersion = 1
        let escapingURL = library.packageURL(for: escaping.id)
        try FileManager.default.createDirectory(at: escapingURL, withIntermediateDirectories: true)
        try escaping.encoded().write(to: escapingURL.appending(path: WallpaperLibrary.manifestName))

        let result = library.load()
        #expect(result.wallpapers == [good])
        #expect(Set(result.skipped.map(\.lastPathComponent)) == [renamed.lastPathComponent, escapingURL.lastPathComponent])
        #expect(FileManager.default.fileExists(atPath: renamed.path))
    }
}
