import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    Form {
      Section("Behavior") {
        Toggle(
          "Launch at Login",
          isOn: Binding(
            get: { appState.settings.launchAtLogin },
            set: { value in
              appState.updateSettings { $0.launchAtLogin = value }
            }
          )
        )

        Toggle(
          "Lock Preview by Default",
          isOn: Binding(
            get: { appState.settings.previewLocked },
            set: { value in
              appState.updateSettings { $0.previewLocked = value }
            }
          )
        )
      }

      Section("Hotkey") {
        HotkeyRecorderView()
      }

      Section("Data") {
        Button("Clear All Items") {
          appState.clearAll()
        }
        .foregroundStyle(.red)
      }
    }
    .padding(20)
  }
}
