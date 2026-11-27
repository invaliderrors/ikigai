import IkigaiCore
import IkigaiRender
import SwiftUI

/// The Studio: layers on the left, the live scene in the middle, settings on the right.
struct StudioView: View {
    @State private var studio: StudioModel?
    private let wallpaperID: UUID
    private var app = AppModel.shared

    init(wallpaperID: UUID) {
        self.wallpaperID = wallpaperID
    }

    var body: some View {
        Group {
            if let studio {
                StudioEditor(studio: studio)
            } else {
                ContentUnavailableView("This scene can't be opened", systemImage: "exclamationmark.triangle",
                                       description: Text("It may have been moved to the Trash, or its scene file is damaged."))
            }
        }
        .frame(minWidth: 1080, minHeight: 640)
        .background(Theme.house)
        .preferredColorScheme(.dark)
        .tint(Theme.tungsten)
        .onAppear {
            studio = StudioModel(wallpaperID: wallpaperID)
            app.windowOpened()
        }
        .onDisappear {
            studio?.flush()
            if app.previewing == wallpaperID { app.endPreview() }
            app.windowClosed()
        }
    }
}

private struct StudioEditor: View {
    @Bindable var studio: StudioModel
    private var app = AppModel.shared

    init(studio: StudioModel) {
        self.studio = studio
    }

    var body: some View {
        HStack(spacing: 0) {
            LayersPanel(studio: studio).frame(width: 250)
            Divider().overlay(Theme.line)
            canvas
            Divider().overlay(Theme.line)
            InspectorPanel(studio: studio).frame(width: 300)
        }
        .focusedSceneValue(\.studio, studio)
        .navigationTitle(studio.wallpaper?.manifest.title ?? "Studio")
        .navigationSubtitle(studio.status)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Toolbars hide a toggle's own label, so the words sit beside it.
                HStack(spacing: 8) {
                Text("Live on Desktop").font(.system(size: 12.5))
                Toggle("Live on Desktop", isOn: Binding(
                    get: { app.previewing == studio.wallpaperID },
                    set: { on in
                        guard let wallpaper = studio.wallpaper else { return }
                        on ? app.preview(wallpaper) : app.endPreview()
                    }))
                .toggleStyle(.switch)
                .labelsHidden()
                }
                .help("Try this scene on your desktop while you edit; turn it off to put back what was there")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Show on All Screens") {
                    guard let wallpaper = studio.wallpaper else { return }
                    if app.previewing == wallpaper.id { app.keepPreview() } else { app.showEverywhere(wallpaper) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var canvas: some View {
        VStack(spacing: 12) {
            ScenePreview(host: studio.preview)
                .aspectRatio(screenAspect, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.08)))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
                .accessibilityLabel("Scene preview")
            Text("Move the pointer over your screen to see parallax.")
                .font(.system(size: 12)).foregroundStyle(Theme.screen3)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x120E0C))
    }

    private var screenAspect: CGFloat {
        let size = NSScreen.main?.frame.size ?? CGSize(width: 16, height: 10)
        return size.width / max(size.height, 1)
    }
}

/// Hosts a live scene (the Studio's, the wizard's); swaps in a new renderer view when the preview is rebuilt.
struct ScenePreview: NSViewRepresentable {
    let host: SceneHost?

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let view = host?.view, container.subviews.first !== view else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        view.frame = container.bounds
        view.autoresizingMask = [.width, .height]
        container.addSubview(view)
    }
}

// MARK: Layers

private struct LayersPanel: View {
    @Bindable var studio: StudioModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Layers").font(.system(size: 11, weight: .bold)).textCase(.uppercase).tracking(0.7).foregroundStyle(Theme.screen2)
                Spacer()
                Text("Top to bottom").font(.system(size: 11)).foregroundStyle(Theme.screen3)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            // Rows are tinted buttons rather than system selection, which would draw the grey highlight
            // (DESIGN.md: Tint, Not Fill).
            List {
                // Shown top layer first; the document stores them back to front.
                ForEach(studio.document.layers.indices.reversed(), id: \.self) { index in
                    let selected = studio.selection == index
                    Button { studio.selection = index } label: {
                        LayerRow(layer: studio.document.layers[index], folder: studio.wallpaper?.entryURL.deletingLastPathComponent(),
                                 selected: selected)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selected ? Theme.tungstenTint.clipShape(.rect(cornerRadius: 8)).padding(.horizontal, 6) : nil)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                .onMove { offsets, destination in
                    guard let from = offsets.first else { return }
                    let count = studio.document.layers.count
                    // Convert positions in the top-first list into document indices.
                    let source = count - 1 - from
                    let target = count - 1 - (destination > from ? destination - 1 : destination)
                    studio.moveLayer(from: source, to: target)
                }
            }
            .scrollContentBackground(.hidden)

            HStack(spacing: 6) {
                Button("Add Layer", systemImage: "plus") {
                    if let images = pickImages(multiple: true) { studio.addLayers(images) }
                }
                .labelStyle(.iconOnly)
                .help("Add pictures as new layers on top")
                Button("Remove Layer", systemImage: "minus") { studio.removeSelectedLayer() }
                    .labelStyle(.iconOnly)
                    .disabled(studio.selection == nil || studio.document.layers.count < 2)
                    .help("Remove the selected layer")
                Spacer()
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(10)
        }
        .background(Theme.house2)
    }
}

private struct LayerRow: View {
    let layer: SceneDocument.Layer
    let folder: URL?
    var selected = false
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Theme.house3
                if let thumbnail { Image(nsImage: thumbnail).resizable().scaledToFill() }
            }
            .frame(width: 44, height: 28)
            .clipShape(.rect(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 1) {
                Text((layer.image as NSString).deletingPathExtension).font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.tungsten : Theme.screen).lineLimit(1)
                Text(summary).font(.system(size: 11)).foregroundStyle(Theme.screen3).lineLimit(1)
            }
        }
        .task(id: layer.image) {
            thumbnail = folder.flatMap { NSImage(contentsOf: $0.appending(path: layer.image)) }
        }
    }

    private var summary: String {
        var parts = [layer.effect == .none ? "Still" : layer.effect.rawValue.capitalized]
        if layer.blur > 0 { parts.append("Blur") }
        if layer.glow > 0 { parts.append("Glow") }
        if layer.mask != nil { parts.append("Mask") }
        return parts.joined(separator: " · ")
    }
}

// MARK: Inspector

private struct InspectorPanel: View {
    @Bindable var studio: StudioModel

    var body: some View {
        Form {
            if let layer = studio.selectedLayer {
                Section("Layer") {
                    slider("Depth", value: layer.depth, in: 0...1, help: "How far it moves with the pointer") { $0.depth = $1 }
                    Picker("Motion", selection: Binding(get: { layer.effect }, set: { value in studio.editSelectedLayer { $0.effect = value } })) {
                        ForEach(SceneDocument.Effect.allCases, id: \.self) { effect in
                            Text(effect == .none ? "None" : effect.rawValue.capitalized).tag(effect)
                        }
                    }
                    LabeledContent("Mask") {
                        HStack {
                            Button(layer.mask == nil ? "Choose…" : "Change…") {
                                if let image = pickImages(multiple: false)?.first { studio.setMask(image) }
                            }
                            if layer.mask != nil { Button("Remove") { studio.setMask(nil) } }
                        }
                    }
                    .help("A black-and-white picture: the motion happens where it's white")
                    slider("Blur", value: layer.blur, in: 0...1, help: "Soft focus, for distant layers") { $0.blur = $1 }
                    slider("Glow", value: layer.glow, in: 0...1, help: "A soft pulsing light around bright parts") { $0.glow = $1 }
                }
            }
            Section("Scene") {
                Picker("Particles", selection: Binding(get: { studio.document.particleStyle },
                                                       set: { value in studio.edit { $0.particleStyle = value } })) {
                    ForEach(SceneDocument.ParticleStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                LabeledContent("Amount") {
                    // Rounded in the binding rather than with `step`, which would draw a tick mark every 100.
                    Slider(value: Binding(get: { Double(studio.document.particles) },
                                          set: { value in studio.edit { $0.particles = Int((value / 100).rounded()) * 100 } }),
                           in: 0...Double(SceneDocument.maxParticles))
                }
                sceneSlider("Brightness", \.brightness)
                sceneSlider("Contrast", \.contrast)
                sceneSlider("Saturation", \.saturation)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.house2)
    }

    private func slider(_ title: String, value: Double, in range: ClosedRange<Double>, help: String,
                        set: @escaping (inout SceneDocument.Layer, Double) -> Void) -> some View {
        LabeledContent(title) {
            Slider(value: Binding(get: { value }, set: { new in studio.editSelectedLayer { set(&$0, new) } }), in: range)
        }
        .help(help)
    }

    private func sceneSlider(_ title: String, _ keyPath: WritableKeyPath<SceneDocument.Grade, Double>) -> some View {
        LabeledContent(title) {
            Slider(value: Binding(get: { studio.document.grade[keyPath: keyPath] },
                                  set: { new in studio.edit { $0.grade[keyPath: keyPath] = new } }), in: 0.5...1.5)
        }
    }
}

/// Asks for pictures with the standard open panel.
@MainActor func pickImages(multiple: Bool) -> [URL]? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = multiple
    panel.message = multiple ? "Choose pictures to add as layers." : "Choose a black-and-white mask picture."
    return panel.runModal() == .OK ? panel.urls : nil
}

extension FocusedValues {
    /// The Studio in the focused window, so Edit › Undo and Redo reach it.
    @Entry var studio: StudioModel?
}

/// Edit › Undo and Redo: the focused Studio's history, or the normal responder chain (text fields) elsewhere.
struct UndoCommands: Commands {
    @FocusedValue(\.studio) private var studio

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                if let studio { studio.undo() } else { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
            }
            .keyboardShortcut("z")
            .disabled(studio.map { !$0.history.canUndo } ?? false)
            Button("Redo") {
                if let studio { studio.redo() } else { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(studio.map { !$0.history.canRedo } ?? false)
        }
    }
}
