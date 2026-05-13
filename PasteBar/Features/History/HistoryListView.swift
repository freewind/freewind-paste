import SwiftUI
import UniformTypeIdentifiers

struct HistoryListView: View {
  @Environment(AppState.self) private var appState
  @Environment(ClipViewState.self) private var uiState
  @State private var draggedItemID: String?
  @State private var dropTarget: HistoryDropTarget?
  @State private var rowRegistry = HistoryRowRegistry()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(uiState.visibleItems) { item in
          NativeClickableRow(
            itemID: item.id,
            registry: rowRegistry,
            content: AnyView(
              HistoryRowView(
                item: item,
                isDragActive: draggedItemID != nil,
                isDragged: draggedItemID == item.id,
                dropLine: dropLine(for: item.id)
              )
            ),
            onClick: { event in
              uiState.handleClick(
                on: item.id,
                orderedIDs: uiState.visibleItemIDs,
                modifiers: event.modifierFlags
              )
            },
            onDoubleClick: {
              if uiState.selectedIDs.count <= 1 || !uiState.selectedIDs.contains(item.id) {
                uiState.handleClick(
                  on: item.id,
                  orderedIDs: uiState.visibleItemIDs,
                  modifiers: []
                )
              }
              appState.pasteSelection(mode: .normalEnter)
            }
          )
            .id(item.id)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .contextMenu {
              let targetIDs = contextTargetIDs(for: item)
              let isMultiTarget = targetIDs.count > 1

              if uiState.currentTab != .trash {
                Button("Paste") {
                  appState.paste(targetIDs, mode: .normalEnter)
                }

                Divider()

                Button(uiState.allFavorites(in: targetIDs) ? "Unfavorite" : "Favorite") {
                  appState.setFavorite(targetIDs, favorite: !uiState.allFavorites(in: targetIDs))
                }
                Button(item.label.isEmpty ? "Add Label" : "Edit Label") {
                  appState.promptForLabel(for: item.id)
                }
                .disabled(isMultiTarget)

                Button("Move to Trash") {
                  appState.delete(targetIDs, permanently: false)
                }
              } else {
                Button("Restore") {
                  appState.restore(targetIDs)
                }
                Button("Delete Permanently") {
                  appState.delete(targetIDs, permanently: true)
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
                groupItemIDs: uiState.visibleItemIDs,
                draggedItemID: $draggedItemID,
                dropTarget: $dropTarget,
                onMove: { offsets, destination in
                  appState.moveItems(within: uiState.visibleItemIDs, from: offsets, to: destination)
                }
              )
            )
        }
      }
    }
    .background(
      DragEndMonitorView {
        guard draggedItemID != nil || dropTarget != nil else {
          return
        }
        draggedItemID = nil
        dropTarget = nil
      }
    )
    .onAppear {
      syncFocusedItemVisibility()
    }
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
    .onChange(of: uiState.focusedID) { _, _ in
      guard draggedItemID == nil else {
        return
      }
      syncFocusedItemVisibility()
    }
    .onChange(of: uiState.viewportMoveRequestID) { _, _ in
      guard draggedItemID == nil else {
        return
      }
      performViewportMove()
    }
  }

  private func syncFocusedItemVisibility() {
    guard let focusedID = uiState.focusedID else {
      return
    }

    rowRegistry.revealMinimally(itemID: focusedID, orderedIDs: uiState.visibleItemIDs)
  }

  private func performViewportMove() {
    guard let command = uiState.consumePendingViewportMoveCommand() else {
      return
    }

    let orderedIDs = uiState.visibleItemIDs
    guard !orderedIDs.isEmpty else {
      return
    }

    switch command {
    case let .page(direction):
      rowRegistry.scrollPage(by: direction, orderedIDs: orderedIDs)
    case let .boundary(isStart):
      rowRegistry.scrollToBoundary(isStart: isStart, orderedIDs: orderedIDs)
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
}

@MainActor
private final class HistoryRowRegistry {
  private final class WeakRowView {
    weak var value: NativeClickableHostingView?

    init(_ value: NativeClickableHostingView) {
      self.value = value
    }
  }

  private var views: [String: WeakRowView] = [:]

  func register(_ view: NativeClickableHostingView, for itemID: String) {
    views[itemID] = WeakRowView(view)
    cleanup()
  }

  func unregister(itemID: String, view: NativeClickableHostingView) {
    guard let current = views[itemID]?.value, current === view else {
      return
    }
    views[itemID] = nil
  }

  func revealMinimally(itemID: String, orderedIDs: [String]) {
    cleanup()

    guard
      let scrollView = orderedIDs.lazy.compactMap({ self.views[$0]?.value?.enclosingScrollView }).first,
      let documentView = scrollView.documentView
    else {
      return
    }

    scrollView.layoutSubtreeIfNeeded()
    documentView.layoutSubtreeIfNeeded()

    guard let rowView = views[itemID]?.value else {
      return
    }

    let rowFrame = rowView.convert(rowView.bounds, to: documentView)
    let visibleRect = scrollView.contentView.documentVisibleRect

    if rowFrame.minY >= visibleRect.minY, rowFrame.maxY <= visibleRect.maxY {
      return
    }

    var nextOrigin = visibleRect.origin
    if rowFrame.minY < visibleRect.minY {
      nextOrigin.y = rowFrame.minY
    } else {
      nextOrigin.y = rowFrame.maxY - visibleRect.height
    }

    let maxY = max(documentView.bounds.height - visibleRect.height, 0)
    nextOrigin.y = min(max(nextOrigin.y, 0), maxY)
    scroll(scrollView: scrollView, toY: nextOrigin.y)
  }

  func scrollPage(by direction: Int, orderedIDs: [String]) {
    guard direction != 0 else {
      return
    }

    cleanup()

    guard
      let scrollView = orderedIDs.lazy.compactMap({ self.views[$0]?.value?.enclosingScrollView }).first,
      let documentView = scrollView.documentView
    else {
      return
    }

    let visibleRect = scrollView.contentView.documentVisibleRect
    let maxY = max(documentView.bounds.height - visibleRect.height, 0)
    let nextY = visibleRect.origin.y + (CGFloat(direction) * visibleRect.height)
    scroll(scrollView: scrollView, toY: min(max(nextY, 0), maxY))
  }

  func scrollToBoundary(isStart: Bool, orderedIDs: [String]) {
    cleanup()

    guard
      let scrollView = orderedIDs.lazy.compactMap({ self.views[$0]?.value?.enclosingScrollView }).first,
      let documentView = scrollView.documentView
    else {
      return
    }

    let visibleRect = scrollView.contentView.documentVisibleRect
    let maxY = max(documentView.bounds.height - visibleRect.height, 0)
    scroll(scrollView: scrollView, toY: isStart ? 0 : maxY)
  }

  private func cleanup() {
    views = views.filter { $0.value.value != nil }
  }

  private func scroll(scrollView: NSScrollView, toY y: CGFloat) {
    var nextOrigin = scrollView.contentView.documentVisibleRect.origin
    nextOrigin.y = y
    scrollView.contentView.scroll(to: nextOrigin)
    scrollView.reflectScrolledClipView(scrollView.contentView)
  }
}

private struct NativeClickableRow: NSViewRepresentable {
  let itemID: String
  let registry: HistoryRowRegistry
  let content: AnyView
  let onClick: (NSEvent) -> Void
  let onDoubleClick: () -> Void

  func makeNSView(context: Context) -> NativeClickableHostingView {
    let view = NativeClickableHostingView(rootView: content)
    view.onClick = onClick
    view.onDoubleClick = onDoubleClick
    registry.register(view, for: itemID)
    return view
  }

  func updateNSView(_ nsView: NativeClickableHostingView, context: Context) {
    nsView.rootView = content
    nsView.onClick = onClick
    nsView.onDoubleClick = onDoubleClick
    registry.register(nsView, for: itemID)
  }

  static func dismantleNSView(_ nsView: NativeClickableHostingView, coordinator: ()) {
    // no-op; registry cleanup happens on next register/reveal pass
  }
}

private final class NativeClickableHostingView: NSHostingView<AnyView> {
  var onClick: ((NSEvent) -> Void)?
  var onDoubleClick: (() -> Void)?

  override func mouseDown(with event: NSEvent) {
    if shouldIgnoreRowClick(for: event) {
      super.mouseDown(with: event)
      return
    }

    onClick?(event)
    super.mouseDown(with: event)

    if event.clickCount == 2 {
      onDoubleClick?()
    }
  }

  private func shouldIgnoreRowClick(for event: NSEvent) -> Bool {
    let point = convert(event.locationInWindow, from: nil)
    guard let hitView = hitTest(point) else {
      return false
    }

    return hitView.hasAncestor(before: self) { view in
      view is NSButton || view is NSControl
    }
  }
}

private extension NSView {
  func hasAncestor(before ancestor: NSView, matching: (NSView) -> Bool) -> Bool {
    var current: NSView? = self
    while let view = current, view !== ancestor {
      if matching(view) {
        return true
      }
      current = view.superview
    }
    return false
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
