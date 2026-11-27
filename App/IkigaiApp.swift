import SwiftUI

@main
struct IkigaiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let model = AppModel.shared

    init() {
        Marquee.registerBundledFont()
    }

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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
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
