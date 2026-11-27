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
