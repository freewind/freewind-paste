import SwiftUI

struct HistoryListView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    List(selection: $store.selectedIDs) {
      ForEach(store.groupedVisibleItems) { group in
        Section(group.title) {
          ForEach(group.items) { item in
            HistoryRowView(item: item)
              .tag(item.id)
              .contentShape(Rectangle())
              .onTapGesture {
                store.handleClick(
                  on: item.id,
                  orderedIDs: store.visibleItems.map(\.id),
                  modifiers: NSEvent.modifierFlags
                )
              }
              .onTapGesture(count: 2) {
                store.handleClick(
                  on: item.id,
                  orderedIDs: store.visibleItems.map(\.id),
                  modifiers: []
                )
                appState.pasteSelection(mode: .normalEnter)
              }
              .contextMenu {
                if store.currentTab != .trash {
                  Button(item.favorite ? "Unfavorite" : "Favorite") {
                    store.toggleFavorite(for: item.id)
                    appState.persistItems()
                  }
                  Button(item.label.isEmpty ? "Add Label" : "Edit Label") {
                    appState.promptForLabel(for: item.id)
                  }
                  Button("Move to Trash") {
                    store.delete(item.id)
                    appState.persistItems()
                  }
                } else {
                  Button("Restore") {
                    appState.restore(item.id)
                  }
                  Button("Delete Permanently") {
                    store.delete([item.id], permanently: true)
                    appState.persistItems()
                  }
                }
              }
          }
          .onMove { offsets, destination in
            store.moveItems(
              within: group.items.map(\.id),
              from: offsets,
              to: destination
            )
            appState.persistItems()
          }
        }
      }
    }
    .listStyle(.sidebar)
    .controlSize(.small)
    .environment(\.defaultMinListRowHeight, 26)
    .onChange(of: store.selectedIDs) { _, newValue in
      if let id = newValue.first {
        store.focusedID = id
      }
    }
  }
}
