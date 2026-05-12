import SwiftUI

struct HistoryView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 8) {
        SearchBarView()
          .padding(.horizontal, 12)
          .padding(.top, 10)

        Picker("", selection: $store.currentTab) {
          Text("History").tag(MainTab.history)
          Text("Favorites").tag(MainTab.favorites)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
      }

      Divider()

      NavigationSplitView {
        VStack(spacing: 8) {
          HistoryListView()

          sidebarFooter
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 460, maxHeight: .infinity)
      } detail: {
        PreviewPaneView()
      }
    }
    .frame(minWidth: 960, minHeight: 620)
    .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 460)
  }

  private var sidebarFooter: some View {
    HStack(spacing: 8) {
      Button {
          store.setVisibleChecked(!store.allVisibleChecked)
      } label: {
        Image(systemName: store.visibleCheckedState.iconName)
          .foregroundStyle(store.checkedVisibleCount > 0 ? Color.accentColor : Color.secondary)
      }

      Text("\(store.checkedVisibleCount)")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(minWidth: 18, alignment: .leading)

      Button("Delete Checked") {
        store.deleteCheckedVisible()
        appState.persistItems()
      }
      .disabled(store.checkedVisibleCount == 0)

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
    .padding(.top, 4)
  }
}
