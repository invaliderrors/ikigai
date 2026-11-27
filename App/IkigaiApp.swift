import SwiftUI

@main
struct IkigaiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private let model = AppModel.shared

    init() {
        Marquee.registerBundledFont()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            MenuBarIcon()
        }
        Window("Ikigai", id: WindowID.library) {
            LibraryView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultLaunchBehavior(.suppressed)
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
    }

    /// Opening Ikigai again (Finder, Spotlight, the Dock) shows the Library, as people expect.
    /// `hasVisibleWindows` is no guide here: the desktop wallpaper windows always count as visible.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        AppModel.shared.libraryRequests += 1
        return true
    }
}

/// The menu bar icon is the one view that always exists, so it carries the window-opening requests.
struct MenuBarIcon: View {
    private var model = AppModel.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: model.intermissions.isEmpty ? "sparkles.rectangle.stack" : "pause.rectangle")
            .accessibilityLabel(model.intermissions.isEmpty ? "Ikigai" : "Ikigai, intermission")
            // .task(id:) also runs on first appearance, so a request made during launch isn't lost.
            .task(id: model.libraryRequests) {
                guard model.libraryRequests > 0 else { return }
                openWindow(id: WindowID.library)
                NSApp.activate()
            }
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
