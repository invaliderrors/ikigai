import Foundation
import IkigaiCore
import IkigaiRender
import Observation

/// One Studio window's working copy of a scene. Edits show at once; saving happens on its own
/// half a second after the last change, and a save that wouldn't load is never written.
@MainActor @Observable final class StudioModel {
    let wallpaperID: UUID
    private(set) var document: SceneDocument
    /// Index into `document.layers` (back to front).
    var selection: Int?
    private(set) var status = "Saved"
    private(set) var preview: SceneHost?

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var rebuildTask: Task<Void, Never>?
    private var app: AppModel { AppModel.shared }

    init?(wallpaperID: UUID) {
        guard let wallpaper = AppModel.shared.wallpaper(id: wallpaperID), wallpaper.manifest.kind == .scene,
              let document = try? AppModel.shared.library.scene(of: wallpaper) else { return nil }
        self.wallpaperID = wallpaperID
        self.document = document
        selection = document.layers.indices.last
        rebuildPreview()
    }

    var wallpaper: InstalledWallpaper? { app.wallpaper(id: wallpaperID) }

    var selectedLayer: SceneDocument.Layer? {
        selection.flatMap { document.layers.indices.contains($0) ? document.layers[$0] : nil }
    }

    // MARK: Editing

    func edit(_ change: (inout SceneDocument) -> Void) {
        change(&document)
        applyToPreview()
        scheduleSave()
    }

    func editSelectedLayer(_ change: (inout SceneDocument.Layer) -> Void) {
        guard let selection, document.layers.indices.contains(selection) else { return }
        edit { change(&$0.layers[selection]) }
    }

    /// Adds pictures as new layers on top.
    func addLayers(_ images: [URL]) {
        guard let wallpaper else { return }
        for image in images {
            do {
                let name = try app.library.addImage(image, to: wallpaper)
                edit { $0.layers.append(SceneDocument.Layer(image: name)) }
                selection = document.layers.count - 1
            } catch {
                app.alert = AppModel.message(for: error, item: image.lastPathComponent)
            }
        }
    }

    /// Uses a picture as the selected layer's mask: white is full effect, black none.
    func setMask(_ image: URL?) {
        guard let wallpaper else { return }
        guard let image else { return editSelectedLayer { $0.mask = nil } }
        do {
            let name = try app.library.addImage(image, to: wallpaper)
            editSelectedLayer { $0.mask = name }
        } catch {
            app.alert = AppModel.message(for: error, item: image.lastPathComponent)
        }
    }

    func removeSelectedLayer() {
        guard let selection, document.layers.count > 1 else { return }  // a scene keeps at least one layer
        edit { $0.layers.remove(at: selection) }
        self.selection = min(selection, document.layers.count - 1)
    }

    func moveLayer(from source: Int, to destination: Int) {
        guard source != destination, document.layers.indices.contains(source), document.layers.indices.contains(destination) else { return }
        edit { $0.layers.move(fromOffsets: [source], toOffset: destination > source ? destination + 1 : destination) }
        selection = destination
    }

    // MARK: Preview and saving

    private var resolved: SceneDocument.Resolved? {
        guard let wallpaper else { return nil }
        return try? SceneDocument.resolve(document, folder: wallpaper.entryURL.deletingLastPathComponent(), package: wallpaper.packageURL)
    }

    /// Cheap edits change the running preview in place; ones that need new textures rebuild it once the
    /// sliders settle, so dragging blur doesn't rebuild on every step.
    private func applyToPreview() {
        guard let resolved else { return }
        if preview?.applyLive(resolved) == true { return }
        rebuildTask?.cancel()
        rebuildTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            rebuildPreview()
        }
    }

    private func rebuildPreview() {
        guard let resolved, let host = SceneHost(scene: resolved) else { return }
        host.setPlaying(true)
        preview = host
    }

    private func scheduleSave() {
        status = "Editing…"
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    func save() {
        guard let wallpaper else { return }
        do {
            try app.library.saveScene(document, to: wallpaper)
            status = "Saved"
            app.sceneSaved(wallpaper)
        } catch {
            status = "Not saved: \(error.localizedDescription)"
        }
    }

    /// Saves anything pending right away (the window is closing).
    func flush() {
        guard saveTask != nil, status != "Saved" else { return }
        saveTask?.cancel()
        save()
    }
}
