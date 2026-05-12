import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    VStack(spacing: 0) {
      toolbar

      NavigationSplitView {
        VStack(spacing: 10) {
          Picker("Tab", selection: $store.currentTab) {
            Text("History").tag(MainTab.history)
            Text("Favorites").tag(MainTab.favorites)
          }
          .pickerStyle(.segmented)

          SearchBarView()

          HistoryListView()
        }
        .padding(14)
      } detail: {
        PreviewPaneView()
      }
    }
    .frame(minWidth: 920, minHeight: 560)
  }

  private var toolbar: some View {
    HStack(spacing: 10) {
      Button("Paste") {
        appState.pasteSelection(mode: .normalEnter)
      }
      .keyboardShortcut(.return, modifiers: [])

      Button("Native Paste") {
        appState.pasteSelection(mode: .nativeShiftEnter)
      }
      .keyboardShortcut(.return, modifiers: [.shift])

      Button("Reverse") {
        store.reverseSelection()
        appState.persistItems()
      }

      Button("Delete") {
        store.deleteSelected()
        appState.persistItems()
      }

      Button(store.previewLocked ? "Unlock Preview" : "Lock Preview") {
        appState.updateSettings {
          $0.previewLocked.toggle()
        }
      }

      Spacer()

      Text(appState.statusMessage)
        .font(.caption)
        .foregroundStyle(.secondary)

      Button("Settings") {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
      }
    }
    .padding(14)
    .background(Color(NSColor.windowBackgroundColor))
  }
}
