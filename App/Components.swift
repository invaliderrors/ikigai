import IkigaiCore
import IkigaiDesktop
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// A shareable `.ikigai` file, declared in project.yml.
    static let ikigaiWallpaper = UTType(exportedAs: "com.invaliderrors.ikigai.wallpaper")
}

/// Asks where to save a wallpaper's `.ikigai` file, then exports it.
@MainActor func exportWithSavePanel(_ wallpaper: InstalledWallpaper, model: AppModel) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.ikigaiWallpaper]
    panel.nameFieldStringValue = "\(wallpaper.manifest.title).\(WallpaperLibrary.packageExtension)"
    panel.message = "Anyone with Ikigai can open this file to add the wallpaper to their library."
    guard panel.runModal() == .OK, let url = panel.url else { return }
    model.export(wallpaper, to: url)
}

// MARK: Buttons

/// The one tungsten fill per screen. Disabled, it fades so it never looks pressable.
struct PrimaryButtonStyle: ButtonStyle {
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        Filled(configuration: configuration, large: large)
    }

    private struct Filled: View {
        let configuration: Configuration
        let large: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: large ? 14 : 13, weight: .semibold))
                .foregroundStyle(Theme.tungstenInk)
                .padding(.horizontal, large ? 18 : 13)
                .frame(minHeight: large ? 38 : 30)
                .background(Theme.tungsten, in: .rect(cornerRadius: large ? 10 : 8))
                .shadow(color: .black.opacity(isEnabled ? 0.4 : 0), radius: 1, y: 1)
                .opacity(!isEnabled ? 0.35 : configuration.isPressed ? 0.85 : 1)
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var tint = Theme.screen

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 13)
            .frame(minHeight: 30)
            .background(configuration.isPressed ? Theme.house4 : Theme.house3, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.line))
    }
}

// MARK: Tags

/// A removable tag. The remove button is named for VoiceOver ("Remove tag anime").
struct TagChip: View {
    let tag: String
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(tag).font(.system(size: 11.5))
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.screen2)
            .accessibilityLabel("Remove tag \(tag)")
        }
        .foregroundStyle(Theme.screen)
        .padding(.horizontal, 9)
        .frame(height: 22)
        .background(Theme.line2, in: .capsule)
    }
}

/// Lays children out left to right, wrapping onto new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width += spacing + size.width
                rows[rows.count - 1].height = max(last.height, size.height)
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}

// MARK: Letter board

/// The marquee label above each screen: "2 · ALPINE DAWN". Dim when nothing plays there.
struct LetterBoard: View {
    var lead: String
    var feature: String
    var dim = false
    var size: CGFloat = 14

    var body: some View {
        (Text("\(lead) · ") + Text(feature).foregroundStyle(dim ? Theme.screen2 : Theme.tungsten))
            .marquee(size, tracking: 0.12)
            .foregroundStyle(Theme.screen)
            .lineLimit(1)
            .padding(.horizontal, size * 0.8)
            .padding(.vertical, size * 0.36)
            .background(Theme.boothBlack)
            .overlay(Rectangle().strokeBorder(dim ? Theme.line2 : Theme.tungsten.opacity(0.38)))
            .padding(3)
            .background(Theme.boothBlack)
            .shadow(color: .black.opacity(0.5), radius: 4, y: 3)
    }
}

// MARK: Wallpaper image

/// A wallpaper's preview still, or its kind's symbol when it has none (web wallpapers in Phase 1).
struct WallpaperImage: View {
    let wallpaper: InstalledWallpaper?
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Theme.house3
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else if let wallpaper {
                Image(systemName: wallpaper.manifest.kind.symbol)
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.screen3)
            }
        }
        .clipped()
        .task(id: "\(wallpaper?.id.uuidString ?? "")-\(AppModel.shared.previewRevision)") {
            image = wallpaper.flatMap { NSImage(contentsOf: $0.previewURL) }
        }
    }
}

extension WallpaperManifest.Kind {
    var symbol: String {
        switch self {
        case .scene: "square.3.layers.3d"
        case .video: "film"
        case .web: "chevron.left.forwardslash.chevron.right"
        }
    }

    var label: String {
        switch self {
        case .scene: "Scene"
        case .video: "Video"
        case .web: "Web"
        }
    }
}

// MARK: Display strip

/// The signature: the user's real screens at true aspect, each under a letter board,
/// casting its wallpaper's light below. Dark and dimmed when nothing plays.
struct DisplayStrip: View {
    var model: AppModel
    var maxPanelHeight: CGFloat = 135
    var boardSize: CGFloat = 14
    var onTap: ((ScreenInfo) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let scale = scale(for: proxy.size.width)
            HStack(alignment: .bottom, spacing: 22) {
                ForEach(model.screens) { screen in
                    ScreenPanel(model: model, screen: screen, size: CGSize(width: screen.frame.width * scale, height: screen.frame.height * scale),
                                boardSize: boardSize, onTap: onTap)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, maxPanelHeight * 0.22)
        }
        .frame(height: maxPanelHeight * 1.65 + boardSize * 2)
        .background(
            RadialGradient(colors: [Color(hex: 0x2B1F18), Color(hex: 0x120D0B)], center: .bottom, startRadius: 0, endRadius: 520),
            in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line))
        .clipShape(.rect(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your screens")
    }

    /// One scale for every screen keeps their real proportions to each other; shrink further to fit the width.
    private func scale(for width: CGFloat) -> CGFloat {
        let frames = model.screens.map(\.frame)
        guard let tallest = frames.map(\.height).max(), tallest > 0 else { return 0 }
        let byHeight = maxPanelHeight / tallest
        let gaps = CGFloat(max(frames.count - 1, 0)) * 22 + 40
        let byWidth = (width - gaps) / frames.map(\.width).reduce(0, +)
        return min(byHeight, byWidth)
    }
}

private struct ScreenPanel: View {
    var model: AppModel
    var screen: ScreenInfo
    var size: CGSize
    var boardSize: CGFloat
    var onTap: ((ScreenInfo) -> Void)?

    var body: some View {
        let wallpaper = model.wallpaper(on: screen)
        let intermission = model.intermissions[screen.id]
        let number = model.number(of: screen)
        Group {
            if let onTap {
                // A real button when it does something, so the keyboard and VoiceOver can use it.
                Button { onTap(screen) } label: { panel(wallpaper: wallpaper, intermission: intermission, number: number) }
                    .buttonStyle(.plain)
            } else {
                panel(wallpaper: wallpaper, intermission: intermission, number: number)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Screen \(number), \(screen.name)")
        .accessibilityValue(intermission.map { "Intermission, \($0.reason)" } ?? wallpaper?.manifest.title ?? "Dark")
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
    }

    private func panel(wallpaper: InstalledWallpaper?, intermission: Intermission?, number: Int) -> some View {
        VStack(spacing: boardSize * 0.8) {
            if let intermission {
                LetterBoard(lead: "\(number)", feature: "Intermission", dim: true, size: boardSize)
                    .help(intermission.reason)
            } else {
                LetterBoard(lead: "\(number)", feature: wallpaper?.manifest.title ?? "Dark", dim: wallpaper == nil, size: boardSize)
            }
            WallpaperImage(wallpaper: wallpaper)
                .frame(width: size.width, height: size.height)
                .clipShape(.rect(cornerRadius: 6))
                .saturation(intermission == nil ? 1 : 0.3)
                .brightness(intermission == nil ? 0 : -0.35)
                .background {
                    if wallpaper != nil, intermission == nil {
                        // The screen's own light spilling onto the booth wall: the only colored light in the app.
                        WallpaperImage(wallpaper: wallpaper)
                            .frame(width: size.width * 1.3, height: size.height * 0.8)
                            .blur(radius: 26)
                            .opacity(0.5)
                            .offset(y: size.height * 0.55)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if size.width > 70 {
                        Text(intermission?.reason ?? screen.name)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Theme.boothBlack.opacity(0.75), in: .rect(cornerRadius: 5))
                            .padding(7)
                            .lineLimit(1)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.1)))
        }
        .contentShape(.rect)
    }
}
