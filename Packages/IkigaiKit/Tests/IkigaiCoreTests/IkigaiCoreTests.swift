import Foundation
import Testing
@testable import IkigaiCore

@Test func manifestRoundTrips() throws {
    let manifest = WallpaperManifest(title: "Sunset", kind: .scene, entry: "scene.json", tags: ["landscape"])
    #expect(try WallpaperManifest.decode(from: manifest.encoded()) == manifest)
}

@Test func newerFormatIsRefused() throws {
    var manifest = WallpaperManifest(title: "Future", kind: .video, entry: "clip.mp4")
    manifest.formatVersion = WallpaperManifest.currentFormatVersion + 1
    #expect(throws: WallpaperManifest.DecodingFailure.newerFormat(found: 2, supported: 1)) {
        try WallpaperManifest.decode(from: manifest.encoded())
    }
}

@Test(arguments: ["../secret", "../../etc/passwd", "assets/../../x", ".", ""])
func pathsCannotEscapeThePackage(_ path: String) {
    #expect(PackagePath.resolve(path, in: URL(filePath: "/tmp/Sunset.ikigai")) == nil)
}

@Test func pathsInsideThePackageResolve() {
    let url = PackagePath.resolve("assets/sky.png", in: URL(filePath: "/tmp/Sunset.ikigai"))
    #expect(url?.path == "/tmp/Sunset.ikigai/assets/sky.png")
}
