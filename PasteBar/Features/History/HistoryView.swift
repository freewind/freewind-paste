import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    VStack(spacing: 0) {
      SearchBarView()
        .padding(.horizontal, 12)
        .padding(.vertical, 10)

      Divider()

      NavigationSplitView {
        VStack(spacing: 8) {
          HistoryListView()

          sidebarFooter
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 460, maxHeight: .infinity)
      } detail: {
        PreviewPaneView()
      }
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
        Button(store.allVisibleChecked ? "Uncheck All" : "Check All") {
          store.setVisibleChecked(!store.allVisibleChecked)
        }

        if store.checkedVisibleCount > 0 {
          Button("Delete Checked") {
            store.deleteCheckedVisible()
            appState.persistItems()
          }
        }

        Button("Reverse") {
          store.reverseSelection()
          appState.persistItems()
        }

        Button("Delete") {
          store.deleteSelected()
          appState.persistItems()
        }

        Spacer()

        Menu("More") {
          if store.checkedVisibleCount > 0 {
            Button("Clear Visible Checks") {
              store.clearCheckedVisible()
            }
          }
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

      if store.checkedVisibleCount > 0 {
        HStack {
          Text("Checked in current result: \(store.checkedVisibleCount)")
            .font(.caption2)
            .foregroundStyle(.secondary)
          Spacer()
        }
      }
    }
    .padding(.top, 4)
  }
}
