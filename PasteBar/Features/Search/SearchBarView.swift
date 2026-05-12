import AppKit
import SwiftUI

struct SearchBarView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState

  var body: some View {
    PopupAwareSearchField(
      text: $uiState.searchQuery,
      focusNonce: appState.searchFocusNonce,
      handlePopupKeyDown: appState.handlePopupKeyDown,
      moveFocus: uiState.moveFocus,
      moveFocusExtendingSelection: uiState.moveFocusExtendingSelection,
      moveSelectionBlock: appState.moveSelectionShortcut
    )
    .frame(height: 38)
    .onChange(of: uiState.searchQuery) { _, _ in
      uiState.selectFirstVisible()
    }
  }
}

private struct PopupAwareSearchField: NSViewRepresentable {
  @Binding var text: String
  let focusNonce: Int
  let handlePopupKeyDown: (NSEvent) -> NSEvent?
  let moveFocus: (Int) -> Void
  let moveFocusExtendingSelection: (Int) -> Void
  let moveSelectionBlock: (Int) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(
      text: $text,
      moveFocus: moveFocus,
      moveFocusExtendingSelection: moveFocusExtendingSelection,
      moveSelectionBlock: moveSelectionBlock
    )
  }

  func makeNSView(context: Context) -> PopupAwareNSSearchField {
    let field = PopupAwareNSSearchField()
    field.delegate = context.coordinator
    field.handlePopupKeyDown = handlePopupKeyDown
    field.font = .systemFont(ofSize: 18)
    field.controlSize = .large
    field.focusRingType = .default
    field.sendsSearchStringImmediately = true
    field.stringValue = text
    context.coordinator.focus(field, nonce: focusNonce)
    return field
  }

  func updateNSView(_ field: PopupAwareNSSearchField, context: Context) {
    field.handlePopupKeyDown = handlePopupKeyDown
    if field.stringValue != text {
      field.stringValue = text
    }
    context.coordinator.focus(field, nonce: focusNonce)
  }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    @Binding private var text: String
    private let moveFocus: (Int) -> Void
    private let moveFocusExtendingSelection: (Int) -> Void
    private let moveSelectionBlock: (Int) -> Void
    private var lastFocusNonce: Int?

    init(
      text: Binding<String>,
      moveFocus: @escaping (Int) -> Void,
      moveFocusExtendingSelection: @escaping (Int) -> Void,
      moveSelectionBlock: @escaping (Int) -> Void
    ) {
      _text = text
      self.moveFocus = moveFocus
      self.moveFocusExtendingSelection = moveFocusExtendingSelection
      self.moveSelectionBlock = moveSelectionBlock
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSSearchField else {
        return
      }
      text = field.stringValue
    }

    func focus(_ field: NSSearchField, nonce: Int) {
      guard lastFocusNonce != nonce else {
        return
      }
      lastFocusNonce = nonce
      DispatchQueue.main.async {
        field.window?.makeFirstResponder(field)
      }
    }

    func control(
      _ control: NSControl,
      textView: NSTextView,
      doCommandBy commandSelector: Selector
    ) -> Bool {
      switch commandSelector {
      case #selector(NSResponder.moveUp(_:)):
        moveFocus(-1)
        return true
      case #selector(NSResponder.moveDown(_:)):
        moveFocus(1)
        return true
      case #selector(NSResponder.moveUpAndModifySelection(_:)):
        moveFocusExtendingSelection(-1)
        return true
      case #selector(NSResponder.moveDownAndModifySelection(_:)):
        moveFocusExtendingSelection(1)
        return true
      case #selector(NSResponder.moveParagraphBackwardAndModifySelection(_:)):
        moveSelectionBlock(-1)
        return true
      case #selector(NSResponder.moveParagraphForwardAndModifySelection(_:)):
        moveSelectionBlock(1)
        return true
      default:
        return false
      }
    }
  }
}

private final class PopupAwareNSSearchField: NSSearchField {
  var handlePopupKeyDown: ((NSEvent) -> NSEvent?)?

  override func keyDown(with event: NSEvent) {
    if handlePopupKeyDown?(event) == nil {
      return
    }
    super.keyDown(with: event)
  }
}
