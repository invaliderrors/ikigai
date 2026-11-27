import IkigaiCore
import SwiftUI

/// The quick-play panel: what's showing, pause or resume, and one-click switching.
struct MenuBarPanel: View {
    @Bindable private var model = AppModel.shared
    @Environment(\.dismiss) private var dismiss

    /// Reasons that stop every screen at once get a banner; per-screen ones show on the strip.
    private var systemIntermission: Intermission? {
        let systemWide: [Intermission] = [.userPaused, .onBattery, .lowPowerMode]
        return systemWide.first { reason in model.intermissions.values.contains(reason) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Now Showing").marquee(22).foregroundStyle(Theme.screen).accessibilityAddTraits(.isHeader)
                Spacer()
                Button(model.userPaused ? "Resume" : "Pause", systemImage: model.userPaused ? "play.fill" : "pause.fill") {
                    model.userPaused.toggle()
                }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut("p", modifiers: [.command, .option])
            }

            if let intermission = systemIntermission {
                Label {
                    (Text("Intermission · \(intermission.reason). ").bold() + Text(explanation(for: intermission)))
                        .font(.system(size: 12.5))
                } icon: {
                    Image(systemName: intermission == .userPaused ? "pause.circle" : "battery.25").foregroundStyle(Theme.tungsten)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.tungsten.opacity(0.1), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.tungsten.opacity(0.28)))
            }

            DisplayStrip(model: model, maxPanelHeight: 64, boardSize: 11)

            if !model.wallpapers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Show everywhere").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.screen2)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(model.wallpapers.prefix(8)) { wallpaper in
                            let showing = !model.screensShowing(wallpaper).isEmpty
                            Button { model.showEverywhere(wallpaper) } label: {
                                WallpaperImage(wallpaper: wallpaper)
                                    .aspectRatio(16 / 10, contentMode: .fit)
                                    .clipShape(.rect(cornerRadius: 7))
                                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(showing ? Theme.tungsten : Theme.line, lineWidth: showing ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                            .help(wallpaper.manifest.title)
                            .accessibilityLabel(wallpaper.manifest.title)
                            .accessibilityValue(showing ? "Showing" : "")
                        }
                    }
                }
            }

            Divider().overlay(Theme.line)

            VStack(spacing: 0) {
                MenuRow(title: "Open Library", symbol: "square.grid.2x2", shortcut: "⌘L") {
                    model.libraryRequests += 1
                    dismiss()
                }
                .keyboardShortcut("l")
                SettingsLink {
                    MenuRowLabel(title: "Settings…", symbol: "gearshape", shortcut: "⌘,")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { NSApp.activate() })
                MenuRow(title: "Quit Ikigai", symbol: "xmark", shortcut: "⌘Q") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(14)
        .frame(width: 372)
        .background(Theme.house2)
        .preferredColorScheme(.dark)
    }

    private func explanation(for intermission: Intermission) -> String {
        switch intermission {
        case .userPaused: "Choose Resume to play again."
        case .onBattery: "Wallpapers play again when you plug in."
        case .lowPowerMode: "Wallpapers play again when Low Power Mode is off."
        default: ""
        }
    }
}

private struct MenuRow: View {
    let title: String
    let symbol: String
    let shortcut: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { MenuRowLabel(title: title, symbol: symbol, shortcut: shortcut) }
            .buttonStyle(.plain)
    }
}

private struct MenuRowLabel: View {
    let title: String
    let symbol: String
    let shortcut: String
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 16).foregroundStyle(Theme.screen2)
            Text(title)
            Spacer()
            Text(shortcut).foregroundStyle(Theme.screen3).accessibilityHidden(true)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(hovering ? Theme.line : .clear, in: .rect(cornerRadius: 7))
        .contentShape(.rect)
        .onHover { hovering = $0 }
    }
}
