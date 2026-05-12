import AppKit
import SwiftUI

struct SearchBarView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState

  var body: some View {
    PopupAwareSearchField(
      text: $uiState.searchQuery,
      focusNonce: appState.searchFocusNonce,
      handlePopupKeyDown: appState.handlePopupKeyDown
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

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
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
    private var lastFocusNonce: Int?

    init(text: Binding<String>) {
      _text = text
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
