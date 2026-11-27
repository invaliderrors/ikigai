import IkigaiCore
import IkigaiRender
import SwiftUI

/// A picture chosen for the wizard; identifiable so it can drive a sheet.
struct WizardRequest: Identifiable {
    let id = UUID()
    let image: URL
}

/// From a Picture: one picture in, a parallax scene out. One decision per step.
struct PictureWizard: View {
    let request: WizardRequest
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    private enum Phase {
        case reading
        case looks(PictureSceneMaker.Prepared)
        case failed(String)
    }

    @State private var phase = Phase.reading
    @State private var look = PictureSceneMaker.Look.goldenHour
    @State private var preview: SceneHost?
    @State private var finishing = false
    private var app = AppModel.shared

    init(request: WizardRequest) {
        self.request = request
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch phase {
            case .reading: reading
            case .looks(let prepared): looks(prepared)
            case .failed(let message): failed(message)
            }
        }
        .padding(28)
        .frame(width: 860, height: 540)  // fits inside the Library at its minimum height
        .background(Theme.house2)
        .preferredColorScheme(.dark)
        .task { await prepare() }
        .onDisappear {
            // Not opened in the Studio: nothing to keep.
            if case .looks(let prepared) = phase, !finishing { try? FileManager.default.removeItem(at: prepared.folder) }
        }
    }

    private var reading: some View {
        Group {
            Text("Reading your picture").marquee(34).foregroundStyle(Theme.screen)
            ZStack {
                Theme.house3
                if let image = NSImage(contentsOf: request.image) { Image(nsImage: image).resizable().scaledToFit() }
            }
            .clipShape(.rect(cornerRadius: 10))
            .frame(maxHeight: .infinity)
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Finding the subject and filling in the background…").foregroundStyle(Theme.screen2)
                Spacer()
                Text("Everything stays on this Mac.").font(.system(size: 12)).foregroundStyle(Theme.screen3)
            }
            footer(canFinish: false)
        }
    }

    private func looks(_ prepared: PictureSceneMaker.Prepared) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pick a look").marquee(34).foregroundStyle(Theme.screen)
                Text(prepared.hasSubject
                     ? "The subject is lifted in front of the background, so it moves with your pointer. Everything stays editable in the Studio."
                     : "No clear subject was found, so the whole picture will drift gently. Everything stays editable in the Studio.")
                    .font(.system(size: 13)).foregroundStyle(Theme.screen2)
            }
            ScenePreview(host: preview)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.08)))
                .frame(maxHeight: .infinity)
                .accessibilityLabel("Preview of \(look.title)")
            HStack(spacing: 8) {
                ForEach(PictureSceneMaker.Look.allCases) { option in
                    Button(option.title) { choose(option, prepared) }
                        .buttonStyle(LookButtonStyle(selected: option == look))
                        .accessibilityAddTraits(option == look ? .isSelected : [])
                }
            }
            footer(canFinish: true)
        }
    }

    private func failed(_ message: String) -> some View {
        Group {
            Text("That picture didn't work").marquee(34).foregroundStyle(Theme.screen)
            Text(message).foregroundStyle(Theme.screen2)
            Spacer()
            HStack { Spacer(); Button("Close") { dismiss() }.buttonStyle(SecondaryButtonStyle()) }
        }
    }

    private func footer(canFinish: Bool) -> some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
                .keyboardShortcut(.cancelAction)
            Button("Open in Studio") { Task { await finish() } }
                .buttonStyle(PrimaryButtonStyle(large: true))
                .disabled(!canFinish || finishing)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: Work

    private func prepare() async {
        let image = request.image
        do {
            let prepared = try await Task.detached { try PictureSceneMaker.prepare(image) }.value
            phase = .looks(prepared)
            choose(look, prepared)
        } catch {
            phase = .failed("Ikigai couldn't read “\(image.lastPathComponent)” as a picture. Try a PNG, JPEG or HEIC file.")
        }
    }

    /// Shows a look live. Looks differ in grade, which is baked into textures, so each choice builds a new preview.
    private func choose(_ option: PictureSceneMaker.Look, _ prepared: PictureSceneMaker.Prepared) {
        look = option
        let scene = PictureSceneMaker.scene(option, hasSubject: prepared.hasSubject)
        guard let resolved = try? SceneDocument.resolve(scene, folder: prepared.folder, package: prepared.folder),
              let host = SceneHost(scene: resolved) else { return }
        host.setPlaying(true)
        preview = host
    }

    private func finish() async {
        guard case .looks(let prepared) = phase else { return }
        finishing = true
        guard let id = await app.createScene(from: prepared, look: look) else { finishing = false; return }
        dismiss()
        openWindow(id: WindowID.studio, value: id)
    }
}

/// A choice among a few options: tinted when selected, never filled (DESIGN.md: Tint, Not Fill).
private struct LookButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Theme.tungsten : Theme.screen)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(selected ? Theme.tungstenTint : Theme.house3, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Theme.tungsten.opacity(0.45) : Theme.line))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
