import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    Form {
      Section("Accessibility") {
        HStack {
          Text("Status")
          Spacer()
          Text(appState.accessibilityGranted ? "Granted" : "Not Granted")
            .foregroundStyle(appState.accessibilityGranted ? .green : .orange)
        }

        Text("PasteBar needs Accessibility permission to auto-paste into the front app.")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack {
          Button("Request Permission") {
            appState.requestAccessibilityPermission()
          }
          Button("Open Accessibility Settings") {
            appState.openAccessibilitySettings()
          }
        }
      }

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
      }

      Section("Hotkey") {
        HotkeyRecorderView()
        Text("Press Record, then hold modifiers and press a key.")
          .font(.caption)
          .foregroundStyle(.secondary)
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
