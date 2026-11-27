import IkigaiCore
import IkigaiDesktop
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Bindable private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow
    @State private var selection: UUID?
    @State private var search = ""
    @State private var kind: WallpaperManifest.Kind?
    @State private var tagFilter: String?
    @State private var choosingFiles = false
    @State private var dropTargeted = false
    @State private var wizard: WizardRequest?

    private var selected: InstalledWallpaper? { model.wallpaper(id: selection) }

    private var filtered: [InstalledWallpaper] {
        model.wallpapers.filter { wallpaper in
            (kind == nil || wallpaper.manifest.kind == kind)
                && (tagFilter == nil || wallpaper.manifest.tags.contains { $0.caseInsensitiveCompare(tagFilter!) == .orderedSame })
                && (search.isEmpty || wallpaper.manifest.title.localizedCaseInsensitiveContains(search)
                    || wallpaper.manifest.tags.contains { $0.localizedCaseInsensitiveContains(search) })
        }
    }

    var body: some View {
        NavigationSplitView {
            // Selection is a tungsten tint, not the system accent fill (DESIGN.md: Tint, Not Fill).
            List {
                Section("Play") {
                    sidebarRow("Library", symbol: "square.grid.2x2", count: model.wallpapers.count, selected: tagFilter == nil) {
                        tagFilter = nil
                    }
                }
                if !model.allTags.isEmpty {
                    Section("Tags") {
                        ForEach(model.allTags, id: \.name) { tag in
                            sidebarRow(tag.name, symbol: "tag", count: tag.count, selected: tagFilter?.lowercased() == tag.name.lowercased()) {
                                tagFilter = tag.name
                            }
                        }
                    }
                }
            }
            .onChange(of: model.allTags.map(\.name)) { _, names in
                // The tag being shown was removed from its last wallpaper: go back to everything.
                if let tagFilter, !names.contains(where: { $0.caseInsensitiveCompare(tagFilter) == .orderedSame }) { self.tagFilter = nil }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.sidebar)
            .navigationSplitViewColumnWidth(220)
        } detail: {
            content
                .inspector(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selection = nil } })) {
                    if let selected {
                        WallpaperInspector(model: model, wallpaper: selected)
                            .id(selected.id)  // fresh edit fields for each wallpaper
                            .inspectorColumnWidth(min: 280, ideal: 320, max: 380)
                    }
                }
        }
        .toolbar(removing: .title)
        .toolbar {
            if #available(macOS 26, *) {
                // A title, not a control: keep it off the glass capsule toolbar buttons get.
                ToolbarItem(placement: .navigation) { libraryTitle }.sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .navigation) { libraryTitle }
            }
            ToolbarItem(placement: .principal) {
                Picker("Type", selection: $kind) {
                    Text("All").tag(WallpaperManifest.Kind?.none)
                    Text("Scenes").tag(WallpaperManifest.Kind?.some(.scene))
                    Text("Videos").tag(WallpaperManifest.Kind?.some(.video))
                    Text("Web").tag(WallpaperManifest.Kind?.some(.web))
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Import…") { choosingFiles = true }
                    Button("New Scene from Image…") { newScene() }
                } label: {
                    Label("New", systemImage: "plus")
                } primaryAction: {
                    choosingFiles = true
                }
                .help("Import a wallpaper, or start a scene from a picture")
            }
        }
        .searchable(text: $search, placement: .toolbar, prompt: "Search wallpapers")
        .sheet(item: $wizard) { PictureWizard(request: $0) }
        .task {
            if let image = model.pendingWizardImage {
                model.pendingWizardImage = nil
                wizard = WizardRequest(image: image)
            }
        }
        .fileImporter(isPresented: $choosingFiles, allowedContentTypes: [.movie, .folder, .ikigaiWallpaper], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.importItems(urls) }
        }
        .alert("Something went wrong", isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK") {}
        } message: {
            Text(model.alert ?? "")
        }
        .preferredColorScheme(.dark)
        .onAppear { model.windowOpened() }
        .onDisappear { model.windowClosed() }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DisplayStrip(model: model) { screen in
                    if let selected { model.show(selected, on: screen) }
                }
                .help(selected.map { "Click a screen to show “\($0.manifest.title)” there" } ?? "")

                if model.wallpapers.isEmpty {
                    EmptyBill { choosingFiles = true }
                } else {
                    header
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 18) {
                        ForEach(filtered) { wallpaper in
                            WallpaperTile(model: model, wallpaper: wallpaper, isSelected: wallpaper.id == selection) {
                                selection = wallpaper.id
                            }
                        }
                    }
                    if filtered.isEmpty {
                        Text(search.isEmpty ? "No wallpapers here yet." : "No wallpapers match “\(search)”.")
                            .foregroundStyle(Theme.screen2).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
        }
        .background(Theme.house)
        .dropDestination(for: URL.self) { urls, _ in
            model.importItems(urls)
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.tungsten, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
    }

    private func sidebarRow(_ title: String, symbol: String, count: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .badge(Text("\(count)").foregroundStyle(Theme.screen2))
                .foregroundStyle(selected ? Theme.tungsten : Theme.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(selected ? Theme.tungstenTint.clipShape(.rect(cornerRadius: 8)).padding(.horizontal, 10) : nil)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Starts the picture wizard, which builds a parallax scene and opens it in the Studio.
    private func newScene() {
        guard let image = pickImages(multiple: false)?.first else { return }
        wizard = WizardRequest(image: image)
    }

    private var libraryTitle: some View {
        Text("Library").marquee(24).foregroundStyle(Theme.screen).accessibilityAddTraits(.isHeader)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("All wallpapers").font(.system(size: 13, weight: .semibold))
            Text("\(model.wallpapers.count)").font(.system(size: 12)).foregroundStyle(Theme.screen2)
            if model.importsInFlight > 0 {
                ProgressView().controlSize(.small)
                Text("Importing…").font(.system(size: 12)).foregroundStyle(Theme.screen2)
            }
            Spacer()
            if model.skippedCount > 0 {
                Text("\(model.skippedCount) couldn't be opened").font(.system(size: 12)).foregroundStyle(Theme.stop)
                    .help("These packages are damaged or from a newer Ikigai. They stay in the library folder untouched.")
            }
        }
    }
}

private struct WallpaperTile: View {
    var model: AppModel
    let wallpaper: InstalledWallpaper
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        let showing = model.screensShowing(wallpaper)
        // A real button, so Full Keyboard Access and VoiceOver can reach and activate it.
        Button(action: select) { label(showing: showing) }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture(count: 2).onEnded { model.showEverywhere(wallpaper) })
            .contextMenu {
                Button("Show on All Screens") { model.showEverywhere(wallpaper) }
                ForEach(model.screens) { screen in
                    Button("Show on Screen \(model.number(of: screen)) (\(screen.name))") { model.show(wallpaper, on: screen) }
                }
                Divider()
                Button("Export…") { exportWithSavePanel(wallpaper, model: model) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([wallpaper.packageURL]) }
                Button("Move to Trash", role: .destructive) { model.moveToTrash(wallpaper) }
            }
            .accessibilityLabel(wallpaper.manifest.title)
            .accessibilityValue(showing.isEmpty ? wallpaper.manifest.kind.label : "Showing on \(showing.map { "Screen \(model.number(of: $0))" }.joined(separator: ", "))")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(named: "Show on All Screens") { model.showEverywhere(wallpaper) }
    }

    private func label(showing: [ScreenInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            WallpaperImage(wallpaper: wallpaper)
                .aspectRatio(16 / 10, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.08)))
                .overlay(alignment: .topLeading) {
                    if !showing.isEmpty {
                        Label(showing.map { "Screen \(model.number(of: $0))" }.joined(separator: ", "), systemImage: "display")
                            .font(.system(size: 11, weight: .semibold))
                            .labelStyle(TintedIconLabel())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.boothBlack.opacity(0.85), in: .rect(cornerRadius: 6))
                            .padding(8)
                    }
                }
                .padding(isSelected ? 3 : 0)
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(isSelected ? Theme.tungsten : .clear, lineWidth: 2))
            HStack(alignment: .firstTextBaseline) {
                Text(wallpaper.manifest.title).font(.system(size: 12.5)).lineLimit(2)
                Spacer(minLength: 6)
                Text(wallpaper.manifest.kind.label).font(.system(size: 11.5)).foregroundStyle(Theme.screen3)
            }
        }
        .contentShape(.rect)
    }
}

/// White text with a tungsten icon: badges on artwork stay readable on any image.
private struct TintedIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(Theme.tungsten)
            configuration.title.foregroundStyle(Theme.screen)
        }
    }
}

private struct EmptyBill: View {
    let importFiles: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.tungsten)
            Text("Nothing on the bill yet").marquee(32).foregroundStyle(Theme.screen)
            Text("Drop a video, a web folder or an .ikigai file here, or import one.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.screen2)
            HStack(spacing: 10) {
                Button("Import…", action: importFiles)
                    .buttonStyle(PrimaryButtonStyle(large: true))
                Button("Add Starter Pack") { Task { await AppModel.shared.installStarterPack() } }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(AppModel.shared.installingStarterPack)
            }
            .padding(.top, 6)
        }
        .padding(44)
        .frame(maxWidth: 560)
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line2, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private struct WallpaperInspector: View {
    var model: AppModel
    let wallpaper: InstalledWallpaper
    @Environment(\.openWindow) private var openWindow
    @State private var title = ""
    @State private var newTag = ""
    @FocusState private var titleFocused: Bool

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details").font(.system(size: 12, weight: .bold)).textCase(.uppercase).tracking(0.7).foregroundStyle(Theme.screen2)
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleFocused)
                .onSubmit(saveTitle)
                .onChange(of: titleFocused) { _, focused in if !focused { saveTitle() } }
            if !wallpaper.manifest.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(wallpaper.manifest.tags, id: \.self) { tag in
                        TagChip(tag: tag) {
                            model.update(wallpaper, title: wallpaper.manifest.title, tags: wallpaper.manifest.tags.filter { $0 != tag })
                        }
                    }
                }
            }
            TextField("Add tag", text: $newTag)
                .textFieldStyle(.roundedBorder)
                .onSubmit(addTags)
                .help("Separate several tags with commas")
        }
        .onAppear { title = wallpaper.manifest.title }
    }

    private func saveTitle() {
        model.update(wallpaper, title: title, tags: wallpaper.manifest.tags)
        if title.trimmingCharacters(in: .whitespaces).isEmpty { title = wallpaper.manifest.title }
    }

    private func addTags() {
        let added = newTag.split(separator: ",").map(String.init)
        model.update(wallpaper, title: wallpaper.manifest.title, tags: wallpaper.manifest.tags + added)
        newTag = ""
    }

    var body: some View {
        let showing = model.screensShowing(wallpaper)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                WallpaperImage(wallpaper: wallpaper)
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
                Text(wallpaper.manifest.title).marquee(30).foregroundStyle(Theme.screen).lineLimit(3)

                // One size; rank by weight and case (the One Size Inspector Rule).
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    fact("Showing", showing.isEmpty ? "Not showing" : showing.map { "Screen \(model.number(of: $0))" }.joined(separator: ", "))
                    fact("Type", wallpaper.manifest.kind.label)
                    fact("File", wallpaper.entryURL.lastPathComponent)
                }
                .font(.system(size: 12))

                details

                Divider().overlay(Theme.line)

                Text("Show on").font(.system(size: 12, weight: .bold)).textCase(.uppercase).tracking(0.7).foregroundStyle(Theme.screen2)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(model.screens) { screen in
                        let on = showing.contains(screen)
                        Button {
                            on ? model.clear(screen) : model.show(wallpaper, on: screen)
                        } label: {
                            WallpaperImage(wallpaper: on ? wallpaper : model.wallpaper(on: screen))
                                .frame(width: screen.frame.width / screen.frame.height * 44, height: 44)
                                .clipShape(.rect(cornerRadius: 4))
                                .opacity(on ? 1 : 0.55)
                                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(on ? Theme.tungsten : Theme.line2, lineWidth: on ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Screen \(model.number(of: screen))")
                        .accessibilityValue(on ? "Showing" : "Not showing")
                        .help(on ? "Stop showing on Screen \(model.number(of: screen))" : "Show on Screen \(model.number(of: screen))")
                    }
                }
                Button("Show on All Screens") { model.showEverywhere(wallpaper) }
                    .buttonStyle(PrimaryButtonStyle(large: true))
                    .frame(maxWidth: .infinity)

                if wallpaper.manifest.kind == .scene {
                    Button("Edit in Studio", systemImage: "square.3.layers.3d") { openWindow(id: WindowID.studio, value: wallpaper.id) }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: 8) {
                    Button("Export…") { exportWithSavePanel(wallpaper, model: model) }
                        .help("Save a .ikigai file to share this wallpaper")
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([wallpaper.packageURL]) }
                    Button("Move to Trash") { model.moveToTrash(wallpaper) }
                        .buttonStyle(SecondaryButtonStyle(tint: Theme.stop))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(18)
        }
        .background(Theme.house2)
    }

    private func fact(_ term: String, _ value: String) -> some View {
        GridRow {
            Text(term).fontWeight(.bold).textCase(.uppercase).tracking(0.7).foregroundStyle(Theme.screen2)
            Text(value).foregroundStyle(Theme.screen).lineLimit(2)
        }
    }
}
