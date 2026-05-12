import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 8) {
        SearchBarView()
          .padding(.top, 8)

        HistoryListView()

        sidebarFooter
      }
      .padding(.horizontal, 10)
      .padding(.bottom, 8)
      .frame(minWidth: 360, idealWidth: 420, maxWidth: 460, maxHeight: .infinity)
    } detail: {
      PreviewPaneView()
    }
    .frame(minWidth: 960, minHeight: 620)
    .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 460)
  }

  private var sidebarFooter: some View {
    VStack(spacing: 8) {
      Picker("Tab", selection: $store.currentTab) {
        Text("History").tag(MainTab.history)
        Text("Favorites").tag(MainTab.favorites)
      }
      .pickerStyle(.segmented)

      HStack(spacing: 8) {
        Button("Reverse") {
          store.reverseSelection()
          appState.persistItems()
        }

        Button("Delete") {
          store.deleteSelected()
          appState.persistItems()
        }

        Spacer()

        Button(store.previewLocked ? "Unlock" : "Lock") {
          appState.updateSettings {
            $0.previewLocked.toggle()
          }
        }

        Menu("More") {
          Button("Settings") {
            appState.openSettings()
          }
          Button("Clear All") {
            appState.clearAll()
          }
        }
      }
      .buttonStyle(.borderless)
      .font(.caption)
    }
    .padding(.top, 4)
  }
}
