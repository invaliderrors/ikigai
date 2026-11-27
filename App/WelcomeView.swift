import IkigaiCore
import SwiftUI

/// First run: one decision. Clicking a wallpaper plays it on the real desktop at once;
/// nothing is kept until the person says so.
struct WelcomeView: View {
    private var model = AppModel.shared
    @Environment(\.dismissWindow) private var dismissWindow

    private var previewing: InstalledWallpaper? { model.wallpaper(id: model.previewing) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Pick your first wallpaper").marquee(46).foregroundStyle(Theme.screen).accessibilityAddTraits(.isHeader)
                Text("Click one to see it on your desktop. Nothing changes until you keep it.")
                    .font(.system(size: 14)).foregroundStyle(Theme.screen2)
            }

            if model.starterWallpapers.isEmpty {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(model.installingStarterPack ? "Setting up the starter pack…" : "The starter pack isn't available.")
                        .foregroundStyle(Theme.screen2)
                }
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 18) {
                    ForEach(model.starterWallpapers) { wallpaper in
                        let on = model.previewing == wallpaper.id
                        Button { model.preview(wallpaper) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                WallpaperImage(wallpaper: wallpaper)
                                    .aspectRatio(16 / 10, contentMode: .fit)
                                    .clipShape(.rect(cornerRadius: 10))
                                    .overlay(alignment: .topLeading) {
                                        if on {
                                            Label("On your desktop", systemImage: "display")
                                                .font(.system(size: 11, weight: .semibold))
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(Theme.boothBlack.opacity(0.85), in: .rect(cornerRadius: 6))
                                                .padding(8)
                                        }
                                    }
                                    .padding(on ? 3 : 0)
                                    .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(on ? Theme.tungsten : .clear, lineWidth: 2))
                                Text(wallpaper.manifest.title)
                                    .font(.system(size: 12.5, weight: on ? .semibold : .regular))
                                    .foregroundStyle(on ? Theme.tungsten : Theme.screen)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(wallpaper.manifest.title)
                        .accessibilityValue(on ? "On your desktop" : "")
                        .accessibilityHint("Shows it on your desktop to try")
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Import your own") {
                    model.endPreview()
                    model.libraryRequests += 1
                    dismissWindow()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.tungsten)
                .underline()
                Spacer()
                Button("Back to My Wallpaper") {
                    model.endPreview()
                    dismissWindow()
                }
                .buttonStyle(SecondaryButtonStyle())
                Button(previewing.map { "Keep \($0.manifest.title)" } ?? "Keep") {
                    model.keepPreview()
                    dismissWindow()
                }
                .buttonStyle(PrimaryButtonStyle(large: true))
                .disabled(previewing == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 44)
        .padding(.top, 8)
        .padding(.bottom, 30)
        .frame(width: 920)
        .background(Theme.house)
        .preferredColorScheme(.dark)
        // Closing the window is "not now": put the desktop back the way it was.
        .onDisappear { if model.previewing != nil { model.endPreview() } }
    }
}
