import SwiftUI
import UniformTypeIdentifiers

struct HistoryListView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState
  @EnvironmentObject private var store: ClipStore
  @State private var draggedItemID: String?
  @State private var dropTarget: HistoryDropTarget?

  var body: some View {
    List(selection: $uiState.selectedIDs) {
      ForEach(uiState.groupedVisibleItems) { group in
        Section(group.title) {
          ForEach(group.items) { item in
            HistoryRowView(
              item: item,
              isDragged: draggedItemID == item.id,
              dropLine: dropLine(for: item.id)
            )
              .tag(item.id)
              .contentShape(Rectangle())
              .listRowBackground(Color.clear)
              .highPriorityGesture(TapGesture(count: 2).onEnded {
                uiState.handleClick(
                  on: item.id,
                  orderedIDs: uiState.visibleItems.map(\.id),
                  modifiers: []
                )
                appState.pasteSelection(mode: .normalEnter)
              })
              .simultaneousGesture(TapGesture().onEnded {
                uiState.handleClick(
                  on: item.id,
                  orderedIDs: uiState.visibleItems.map(\.id),
                  modifiers: NSEvent.modifierFlags
                )
              })
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
              .onDrag {
                if !uiState.selectedIDs.contains(item.id) {
                  uiState.select([item.id])
                }
                draggedItemID = item.id
                dropTarget = nil
                return NSItemProvider(object: item.id as NSString)
              }
              .onDrop(
                of: [UTType.text],
                delegate: HistoryRowDropDelegate(
                  targetItemID: item.id,
                  groupItemIDs: group.items.map(\.id),
                  draggedItemID: $draggedItemID,
                  dropTarget: $dropTarget,
                  onMove: { offsets, destination in
                    appState.moveItems(within: group.items.map(\.id), from: offsets, to: destination)
                  }
                )
              )
          }
        }
      }
    }
    .listStyle(.sidebar)
    .controlSize(.small)
    .environment(\.defaultMinListRowHeight, 26)
    .background(
      DragEndMonitorView {
        guard draggedItemID != nil || dropTarget != nil else {
          return
        }
        draggedItemID = nil
        dropTarget = nil
      }
    )
    .onChange(of: uiState.selectedIDs) { _, newValue in
      guard draggedItemID == nil else {
        return
      }

      if let focusedID = uiState.focusedID, newValue.contains(focusedID) {
        return
      }

      if let id = uiState.visibleItems.first(where: { newValue.contains($0.id) })?.id {
        uiState.focus(id)
      }
    }
  }

  private func dropLine(for itemID: String) -> HistoryRowView.DropLine {
    guard let dropTarget, dropTarget.itemID == itemID else {
      return .none
    }
    return dropTarget.isAfter ? .after : .before
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

private struct DragEndMonitorView: NSViewRepresentable {
  let onMouseUp: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeNSView(context: Context) -> NSView {
    let view = NSView(frame: .zero)
    context.coordinator.start(onMouseUp: onMouseUp)
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.onMouseUp = onMouseUp
  }

  static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
    coordinator.stop()
  }

  final class Coordinator {
    var monitor: Any?
    var onMouseUp: (() -> Void)?

    func start(onMouseUp: @escaping () -> Void) {
      self.onMouseUp = onMouseUp
      stop()
      monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
        self?.onMouseUp?()
        return event
      }
    }

    func stop() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }
  }
}

private struct HistoryDropTarget: Equatable {
  let itemID: String
  let isAfter: Bool
}

private struct HistoryRowDropDelegate: DropDelegate {
  let targetItemID: String
  let groupItemIDs: [String]
  @Binding var draggedItemID: String?
  @Binding var dropTarget: HistoryDropTarget?
  let onMove: (IndexSet, Int) -> Void

  func dropEntered(info: DropInfo) {
    updateDropTarget(info: info)
  }

  func dropExited(info: DropInfo) {
    guard dropTarget?.itemID == targetItemID else {
      return
    }
    dropTarget = nil
  }

  func performDrop(info: DropInfo) -> Bool {
    guard
      let draggedItemID,
      draggedItemID != targetItemID,
      let from = groupItemIDs.firstIndex(of: draggedItemID),
      let dropTarget,
      dropTarget.itemID == targetItemID,
      let to = groupItemIDs.firstIndex(of: targetItemID)
    else {
      self.draggedItemID = nil
      self.dropTarget = nil
      return false
    }

    if isNoopMove(from: from, to: to, isAfter: dropTarget.isAfter) {
      self.draggedItemID = nil
      self.dropTarget = nil
      return true
    }

    let destination = dropTarget.isAfter ? to + 1 : to
    onMove(IndexSet(integer: from), destination)
    self.draggedItemID = nil
    self.dropTarget = nil
    return true
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    updateDropTarget(info: info)
    return DropProposal(operation: .move)
  }

  func validateDrop(info: DropInfo) -> Bool {
    guard let draggedItemID else {
      return false
    }

    return draggedItemID != targetItemID
  }

  private func updateDropTarget(info: DropInfo) {
    guard
      let draggedItemID,
      draggedItemID != targetItemID
    else {
      return
    }

    let isAfter = info.location.y > 13
    dropTarget = HistoryDropTarget(itemID: targetItemID, isAfter: isAfter)
  }

  private func isNoopMove(from: Int, to: Int, isAfter: Bool) -> Bool {
    if from == to {
      return true
    }
    if isAfter, from == to + 1 {
      return true
    }
    if !isAfter, from + 1 == to {
      return true
    }
    return false
  }
}
