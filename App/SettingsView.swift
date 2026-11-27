import IkigaiCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Performance", systemImage: "bolt") { PerformanceSettings() }
        }
        .frame(width: 560)
        .tint(Theme.tungsten)
        .preferredColorScheme(.dark)
    }
}

private struct GeneralSettings: View {
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        Form {
            Section("Startup") {
                Toggle(isOn: $openAtLogin) {
                    Text("Open Ikigai at login")
                    Text("Your wallpapers come back as soon as you sign in.")
                }
                .onChange(of: openAtLogin) { _, wanted in setOpenAtLogin(wanted) }
                if let error {
                    Text(error).foregroundStyle(Theme.stop).font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.house)
    }

    private func setOpenAtLogin(_ wanted: Bool) {
        let isOn = SMAppService.mainApp.status == .enabled
        guard wanted != isOn else { return }
        do {
            try wanted ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            error = nil
        } catch {
            self.error = "macOS didn't allow this change: \(error.localizedDescription) You can manage login items in System Settings › General › Login Items."
            openAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

private struct PerformanceSettings: View {
    @Bindable private var model = AppModel.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $model.preferences.whenCovered) {
                    Text("A window covers the whole screen")
                    Text("Checked for each screen; the others keep playing.")
                }
                Toggle("An app is in full screen", isOn: $model.preferences.whenFullScreen)
                Toggle(isOn: $model.preferences.onBattery) {
                    Text("On battery")
                    Text("Wallpapers play again when you plug in. Turn this off to play on battery.")
                }
                Toggle("Low Power Mode is on", isOn: $model.preferences.inLowPowerMode)
                LabeledContent {
                    Image(systemName: "lock").foregroundStyle(Theme.screen3)
                } label: {
                    Text("The screen is locked or asleep")
                    Text("Always. Nobody can see it.")
                }
            } header: {
                Text("Intermission when")
            } footer: {
                Text("Video wallpapers are always silent and never keep your Mac awake.")
                    .foregroundStyle(Theme.screen2)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.house)
    }
}
