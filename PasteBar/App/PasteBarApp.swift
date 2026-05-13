import SwiftUI

@main
struct PasteBarApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var appState = AppState()

  var body: some Scene {
    WindowGroup(id: "bootstrap") {
      BootstrapLauncherView(appState: appState) {
        appDelegate.appState = appState
        appState.bootstrapIfNeeded()
      }
    }
    .windowStyle(.hiddenTitleBar)

    Settings {
      SettingsView()
        .environment(appState)
        .environment(appState.uiState)
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

private struct BootstrapLauncherView: NSViewRepresentable {
  let appState: AppState
  let onAppear: () -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    DispatchQueue.main.async {
      onAppear()
      view.window?.setFrame(NSRect(x: 0, y: 0, width: 1, height: 1), display: false)
      view.window?.orderOut(nil)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      nsView.window?.orderOut(nil)
    }
  }
}
