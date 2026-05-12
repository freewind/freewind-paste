import SwiftUI

@main
struct PasteBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var appState = AppState()

  var body: some Scene {
    WindowGroup(id: "bootstrap") {
      Color.clear
        .frame(width: 1, height: 1)
        .onAppear {
          appDelegate.appState = appState
          appState.bootstrapIfNeeded()
        }
    }
    .windowStyle(.hiddenTitleBar)

    Settings {
      SettingsView()
        .environmentObject(appState)
        .environmentObject(appState.uiState)
        .environmentObject(appState.store)
        .frame(width: 520, height: 360)
    }
    .commands {
      CommandGroup(after: .appSettings) {
        Button("Open Clipboard Window") {
          appState.showPopup()
        }
        .keyboardShortcut(",", modifiers: [.command, .shift])
      }
    }
  }
}
