import Foundation
import Testing
@testable import IkigaiCore

struct SceneDocumentTests {
    let sandbox = FileManager.default.temporaryDirectory.appending(path: "ikigai-scene-\(UUID().uuidString)")
    var library: WallpaperLibrary { WallpaperLibrary(root: sandbox.appending(path: "Library"), importLimit: 1_000_000) }

    func sceneFolder(_ json: String, files: [String] = ["sky.png", "trees.png", "trees-mask.png"]) throws -> URL {
        let folder = sandbox.appending(path: "src/Dusk Lake")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in files { try Data([0]).write(to: folder.appending(path: name)) }
        try Data(json.utf8).write(to: folder.appending(path: "scene.json"))
        return folder
    }

    @Test func sceneFolderImportsAndResolves() throws {
        let folder = try sceneFolder("""
            {"version": 1, "particles": 9000, "layers": [
              {"image": "sky.png"},
              {"image": "trees.png", "depth": 4, "effect": "sway", "mask": "trees-mask.png"}]}
            """)
        let scene = try library.importSceneFolder(at: folder)
        #expect(scene.manifest.kind == .scene)
        let resolved = try SceneDocument.load(entry: scene.entryURL, package: scene.packageURL)
        #expect(resolved.layers.count == 2)
        #expect(resolved.layers[0].effect == .none && resolved.layers[0].depth == 0)
        #expect(resolved.layers[1].depth == 1)  // clamped
        #expect(resolved.layers[1].mask?.lastPathComponent == "trees-mask.png")
        #expect(resolved.particles == SceneDocument.maxParticles)  // clamped
        #expect(library.load().wallpapers.map(\.id) == [scene.id])
    }

    @Test func version2ReadsNewFieldsAndClampsThem() throws {
        let folder = try sceneFolder("""
            {"version": 2, "particles": 300, "particleStyle": "embers",
             "grade": {"brightness": 1.1, "contrast": 9, "saturation": -1},
             "layers": [{"image": "sky.png", "effect": "scroll", "blur": 0.4, "glow": 3}]}
            """)
        let scene = try library.importSceneFolder(at: folder)
        let resolved = try SceneDocument.load(entry: scene.entryURL, package: scene.packageURL)
        #expect(resolved.particleStyle == .embers)
        #expect(resolved.layers[0].effect == .scroll)
        #expect(resolved.layers[0].blur == 0.4)
        #expect(resolved.layers[0].glow == 1)
        #expect(resolved.grade == SceneDocument.Grade(brightness: 1.1, contrast: 2, saturation: 0))
    }

    @Test func version1FilesReadWithDefaults() throws {
        let folder = try sceneFolder(#"{"version": 1, "layers": [{"image": "sky.png"}]}"#)
        let scene = try library.importSceneFolder(at: folder)
        let resolved = try SceneDocument.load(entry: scene.entryURL, package: scene.packageURL)
        #expect(resolved.particleStyle == .snow)
        #expect(resolved.grade == .neutral)
        #expect(resolved.layers[0].blur == 0 && resolved.layers[0].glow == 0)
    }

    @Test func layerOutsideThePackageIsRefused() throws {
        let folder = try sceneFolder(#"{"version": 1, "layers": [{"image": "../../../../etc/hosts"}]}"#)
        #expect(throws: WallpaperLibrary.ImportError.invalidPackage) { try library.importSceneFolder(at: folder) }
        #expect(((try? FileManager.default.contentsOfDirectory(atPath: library.root.path)) ?? []).isEmpty)
    }

    @Test func missingImageNewerVersionAndEmptyScenesAreRefused() throws {
        let entry = try sceneFolder(#"{"version": 1, "layers": [{"image": "nope.png"}]}"#).appending(path: "scene.json")
        let package = entry.deletingLastPathComponent()
        #expect(throws: SceneDocument.Failure.missingFile("nope.png")) { try SceneDocument.load(entry: entry, package: package) }

        // A newer file may use effects this build doesn't know; it must say "newer", not "unreadable".
        try Data(#"{"version": 3, "layers": [{"image": "sky.png", "effect": "warp-drive"}]}"#.utf8).write(to: entry)
        #expect(throws: SceneDocument.Failure.newerVersion(found: 3, supported: 2)) { try SceneDocument.load(entry: entry, package: package) }

        try Data(#"{"version": 1, "layers": []}"#.utf8).write(to: entry)
        #expect(throws: SceneDocument.Failure.noLayers) { try SceneDocument.load(entry: entry, package: package) }

        try Data("not json".utf8).write(to: entry)
        #expect(throws: SceneDocument.Failure.unreadable) { try SceneDocument.load(entry: entry, package: package) }
    }
}
