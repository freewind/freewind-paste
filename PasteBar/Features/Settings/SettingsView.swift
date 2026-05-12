import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var appState: AppState

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        sectionCard("Accessibility") {
          HStack {
            Text("Status")
            Spacer()
            Text(appState.accessibilityGranted ? "Granted" : "Not Granted")
              .foregroundStyle(appState.accessibilityGranted ? .green : .orange)
          }

          Text("Needs Accessibility to auto-paste into front app.")
            .font(.caption)
            .foregroundStyle(.secondary)

          Button("Grant / Open Settings") {
            appState.requestAccessibilityPermission()
            appState.openAccessibilitySettings()
          }
        }

        Divider().padding(.vertical, 12)

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

        Divider().padding(.vertical, 12)

        sectionCard("Hotkey") {
          HotkeyRecorderView()
          Text("Press Record, then press modifiers + key.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Divider().padding(.vertical, 12)

        sectionCard("Data", danger: true) {
          Text("Danger zone")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.red)

          Text("Clear all history is destructive and cannot be undone.")
            .font(.caption)
            .foregroundStyle(.secondary)

          Button("Clear All Items") {
            appState.clearAll()
          }
          .foregroundStyle(.red)
        }
      }
      .padding(20)
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
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
      content()
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(danger ? Color.red.opacity(0.08) : Color(NSColor.controlBackgroundColor))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(danger ? Color.red.opacity(0.35) : Color.secondary.opacity(0.15), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}
