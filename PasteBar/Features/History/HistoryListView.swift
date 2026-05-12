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
              .contextMenu {
                Button(item.favorite ? "Unfavorite" : "Favorite") {
                  store.toggleFavorite(for: item.id)
                  appState.persistItems()
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
    .onChange(of: store.selectedIDs) { _, newValue in
      if let id = newValue.first {
        store.focus(id)
      }
    }
  }
}
