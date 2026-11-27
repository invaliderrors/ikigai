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
            MenuBarPanel()
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
        Window("Ikigai", id: WindowID.library) {
            LibraryView()
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultLaunchBehavior(.suppressed)
        WindowGroup("Studio", id: WindowID.studio, for: UUID.self) { $wallpaperID in
            if let wallpaperID { StudioView(wallpaperID: wallpaperID) }
        }
        .defaultSize(width: 1320, height: 820)
        Window("Welcome to Ikigai", id: WindowID.welcome) {
            WelcomeView()
        }
        .windowResizability(.contentSize)
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

    /// Double-clicking an .ikigai file in Finder (or dropping one on the app) adds it to the library.
    func application(_ application: NSApplication, open urls: [URL]) {
        AppModel.shared.importItems(urls)
        AppModel.shared.libraryRequests += 1
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
            .task(id: model.studioRequest) {
                guard let id = model.studioRequest else { return }
                openWindow(id: WindowID.studio, value: id)
                NSApp.activate()
            }
            .task(id: model.welcomeRequests) {
                guard model.welcomeRequests > 0 else { return }
                openWindow(id: WindowID.welcome)
                NSApp.activate()
            }
    }
}

enum WindowID {
    static let library = "library"
    static let welcome = "welcome"
    static let studio = "studio"
}
