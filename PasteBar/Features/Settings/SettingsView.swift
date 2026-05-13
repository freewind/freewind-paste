import SwiftUI

struct SettingsView: View {
  @Environment(AppState.self) private var appState

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        sectionCard("Accessibility") {
          HStack(spacing: 10) {
            Text("Status")
            Spacer()
            Text(appState.accessibilityGranted ? "Granted" : "Not Granted")
              .foregroundStyle(appState.accessibilityGranted ? .green : .orange)
          }

          HStack(spacing: 10) {
            Text("Needs Accessibility to auto-paste into front app.")
              .font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Grant / Open Settings") {
              appState.requestAccessibilityPermission()
              appState.openAccessibilitySettings()
            }
          }
        }

        Divider()

        sectionCard("Behavior") {
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

        Divider()

        sectionCard("Global Hotkey") {
          HotkeyRecorderView(
            title: "Open Popup",
            hotkey: appState.settings.hotkey,
            requiresModifier: true
          ) { hotkey in
            appState.updateSettings { $0.hotkey = hotkey }
          }

          Text("Global hotkey requires modifiers.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Divider()

        sectionCard("Popup Hotkeys") {
          VStack(alignment: .leading, spacing: 10) {
            ForEach(PopupShortcutAction.allCases) { action in
              HotkeyRecorderView(
                title: action.title,
                hotkey: appState.settings.popupHotkeys.hotkey(for: action),
                requiresModifier: false
              ) { hotkey in
                appState.updateSettings { settings in
                  settings.popupHotkeys.set(hotkey, for: action)
                }
              }
            }
          }

          Text("Popup shortcuts allow single keys or combos.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Divider()

        sectionCard("Data", danger: true) {
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Danger zone")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.red)
            Spacer()
            Button("Clear All Items") {
              appState.clearAll()
            }
            .foregroundStyle(.red)
          }

          Text("Clear all history is destructive and cannot be undone.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(18)
    }
    .onAppear {
      appState.refreshAccessibilityStatus()
    }
    .onReceive(Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()) { _ in
      appState.refreshAccessibilityStatus()
    }
  }

  @ViewBuilder
  private func sectionCard(
    _ title: String,
    danger: Bool = false,
    @ViewBuilder content: () -> some View
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
      content()
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(danger ? Color.red.opacity(0.08) : Color(NSColor.controlBackgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(danger ? Color.red.opacity(0.35) : Color.secondary.opacity(0.15), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
