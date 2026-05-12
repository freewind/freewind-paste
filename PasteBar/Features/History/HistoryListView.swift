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
              .contextMenu {
                Button(item.favorite ? "Unfavorite" : "Favorite") {
                  store.toggleFavorite(for: item.id)
                  appState.persistItems()
                }
                Button(item.label.isEmpty ? "Add Label" : "Edit Label") {
                  appState.promptForLabel(for: item.id)
                }
                Button("Delete") {
                  store.delete(item.id)
                  appState.persistItems()
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
    .environment(\.defaultMinListRowHeight, 34)
    .onChange(of: store.selectedIDs) { _, newValue in
      if let id = newValue.first {
        store.focusedID = id
      }
    }
  }
}
