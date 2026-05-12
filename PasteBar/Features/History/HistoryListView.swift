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
                let targetIDs = contextTargetIDs(for: item)
                let isMultiTarget = targetIDs.count > 1

                if store.currentTab != .trash {
                  Button(allFavorites(in: targetIDs) ? "Unfavorite" : "Favorite") {
                    store.setFavorite(targetIDs, favorite: !allFavorites(in: targetIDs))
                    appState.persistItems()
                  }
                  Button(item.label.isEmpty ? "Add Label" : "Edit Label") {
                    appState.promptForLabel(for: item.id)
                  }
                  .disabled(isMultiTarget)

                  Button("Move to Trash") {
                    store.delete(targetIDs, permanently: false)
                    appState.persistItems()
                  }
                } else {
                  Button("Restore") {
                    store.restore(targetIDs)
                    appState.persistItems()
                  }
                  Button("Delete Permanently") {
                    store.delete(targetIDs, permanently: true)
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

  private func contextTargetIDs(for item: ClipItem) -> Set<String> {
    if store.selectedIDs.count > 1, store.selectedIDs.contains(item.id) {
      return store.selectedIDs
    }
    return [item.id]
  }

  private func allFavorites(in ids: Set<String>) -> Bool {
    let targets = store.items.filter { ids.contains($0.id) }
    return !targets.isEmpty && targets.allSatisfy(\.favorite)
  }
}
