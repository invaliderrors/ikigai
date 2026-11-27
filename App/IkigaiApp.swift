import SwiftUI

@main
struct IkigaiApp: App {
    var body: some Scene {
        MenuBarExtra("Ikigai", systemImage: "sparkles.rectangle.stack") {
            MenuBarContent()
        }
        Window("Ikigai", id: WindowID.library) {
            LibraryView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultLaunchBehavior(.suppressed)
    }
}

enum WindowID {
    static let library = "library"
}

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Library…") {
            openWindow(id: WindowID.library)
            NSApp.activate()
        }
        .keyboardShortcut("l")
        Divider()
        Button("Quit Ikigai") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

struct LibraryView: View {
    var body: some View {
        ContentUnavailableView(
            "Your Library Is Empty",
            systemImage: "sparkles.rectangle.stack",
            description: Text("Wallpapers you import or create will appear here.")
        )
    }
}

#Preview {
    LibraryView()
}
