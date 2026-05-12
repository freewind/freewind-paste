import SwiftUI

struct HistoryListView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    List(selection: $uiState.selectedIDs) {
      ForEach(uiState.groupedVisibleItems) { group in
        Section(group.title) {
          ForEach(group.items) { item in
            HistoryRowView(item: item)
              .tag(item.id)
              .contentShape(Rectangle())
              .onTapGesture {
                uiState.handleClick(
                  on: item.id,
                  orderedIDs: uiState.visibleItems.map(\.id),
                  modifiers: NSEvent.modifierFlags
                )
              }
              .onTapGesture(count: 2) {
                uiState.handleClick(
                  on: item.id,
                  orderedIDs: uiState.visibleItems.map(\.id),
                  modifiers: []
                )
                appState.pasteSelection(mode: .normalEnter)
              }
              .contextMenu {
                let targetIDs = contextTargetIDs(for: item)
                let isMultiTarget = targetIDs.count > 1

                if uiState.currentTab != .trash {
                  Button(allFavorites(in: targetIDs) ? "Unfavorite" : "Favorite") {
                    appState.setFavorite(targetIDs, favorite: !allFavorites(in: targetIDs))
                  }
                  Button(item.label.isEmpty ? "Add Label" : "Edit Label") {
                    appState.promptForLabel(for: item.id)
                  }
                  .disabled(isMultiTarget)

                  Button("Move to Trash") {
                    appState.workflowService.delete(targetIDs, permanently: false)
                  }
                } else {
                  Button("Restore") {
                    appState.workflowService.restore(targetIDs)
                  }
                  Button("Delete Permanently") {
                    appState.workflowService.delete(targetIDs, permanently: true)
                  }
                }
              }
          }
          .onMove { offsets, destination in
            appState.moveItems(within: group.items.map(\.id), from: offsets, to: destination)
          }
        }
      }
    }
    .listStyle(.sidebar)
    .controlSize(.small)
    .environment(\.defaultMinListRowHeight, 26)
    .onChange(of: uiState.selectedIDs) { _, newValue in
      if let id = newValue.first {
        uiState.focus(id)
      }
    }
  }

  private func contextTargetIDs(for item: ClipItem) -> Set<String> {
    if uiState.selectedIDs.count > 1, uiState.selectedIDs.contains(item.id) {
      return uiState.selectedIDs
    }
    return [item.id]
  }

  private func allFavorites(in ids: Set<String>) -> Bool {
    let targets = store.items.filter { ids.contains($0.id) }
    return !targets.isEmpty && targets.allSatisfy(\.favorite)
  }
}
