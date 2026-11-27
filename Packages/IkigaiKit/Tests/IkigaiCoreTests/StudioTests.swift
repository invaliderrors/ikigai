import Foundation
import Testing
@testable import IkigaiCore

struct StudioTests {
    let sandbox = FileManager.default.temporaryDirectory.appending(path: "ikigai-studio-\(UUID().uuidString)")
    var library: WallpaperLibrary { WallpaperLibrary(root: sandbox.appending(path: "Library"), importLimit: 1_000_000) }

    func image(_ name: String) throws -> URL {
        let url = sandbox.appending(path: "src/\(name)")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0]).write(to: url)
        return url
    }

    @Test func aSceneStartsFromOnePicture() throws {
        let scene = try library.createScene(from: try image("Rooftop.png"))
        #expect(scene.manifest.kind == .scene)
        #expect(scene.manifest.title == "Rooftop")
        #expect(scene.manifest.tags == [WallpaperLibrary.creationsTag])
        #expect(try library.scene(of: scene).layers.map(\.image) == ["Rooftop.png"])
        #expect(library.load().wallpapers.map(\.id) == [scene.id])
    }

    @Test func addingImagesNeverOverwrites() throws {
        let scene = try library.createScene(from: try image("sky.png"))
        #expect(try library.addImage(try image("sky.png"), to: scene) == "sky-2.png")
        #expect(throws: WallpaperLibrary.ImportError.notAnImage("notes.txt")) { try library.addImage(try image("notes.txt"), to: scene) }
    }

    @Test func savedEditsRoundTrip() throws {
        let scene = try library.createScene(from: try image("sky.png"))
        let trees = try library.addImage(try image("trees.png"), to: scene)
        var document = try library.scene(of: scene)
        document.layers.append(SceneDocument.Layer(image: trees, depth: 0.5, effect: .sway, glow: 0.3))
        document.particleStyle = .petals
        document.particles = 800
        try library.saveScene(document, to: scene)
        let saved = try library.scene(of: scene)
        #expect(saved.layers.count == 2 && saved.layers[1].effect == .sway && saved.particleStyle == .petals)
    }

    @Test func aBrokenEditNeverReplacesAWorkingScene() throws {
        let scene = try library.createScene(from: try image("sky.png"))
        var document = try library.scene(of: scene)
        document.layers.append(SceneDocument.Layer(image: "missing.png"))
        #expect(throws: SceneDocument.Failure.missingFile("missing.png")) { try library.saveScene(document, to: scene) }
        #expect(try library.scene(of: scene).layers.count == 1)
        #expect(library.load().wallpapers.count == 1)
    }
}
