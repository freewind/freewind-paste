import SwiftUI

@main
struct PasteBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var appState = AppState()

  var body: some Scene {
    MenuBarExtra("PasteBar", systemImage: "doc.on.clipboard") {
      VStack(alignment: .leading, spacing: 10) {
        Button("Open Clipboard Window") {
          appState.togglePopup()
        }

        Button("Paste Selected") {
          appState.pasteSelection(mode: .normalEnter)
        }

        Button("Paste Native") {
          appState.pasteSelection(mode: .nativeShiftEnter)
        }

        Divider()

        Text(appState.statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)

        Button("Quit") {
          NSApplication.shared.terminate(nil)
        }
      }
      .padding(12)
      .frame(width: 220)
      .environmentObject(appState)
      .environmentObject(appState.store)
    }

    Settings {
      SettingsView()
        .environmentObject(appState)
        .environmentObject(appState.store)
        .frame(width: 520, height: 360)
    }
  }
}
