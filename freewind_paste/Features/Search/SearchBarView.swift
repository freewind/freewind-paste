import AppKit
import SwiftUI

struct SearchBarView: View {
  @Environment(AppState.self) private var appState
  @Environment(ClipViewState.self) private var uiState

  var body: some View {
    @Bindable var uiState = uiState

    #if DEBUG
    Group {
      PopupAwareSearchField(
        text: $uiState.searchQuery,
        focusNonce: appState.searchFocusNonce
      )
      .frame(height: 48)
      .pasteDebugNode(
        id: "search_field",
        role: "text_field",
        label: "Popup search field",
        actions: ["set"]
      )
    }
    .environment(appState.debugBridge.registry)
    #else
    PopupAwareSearchField(
      text: $uiState.searchQuery,
      focusNonce: appState.searchFocusNonce
    )
    .frame(height: 48)
    #endif
  }
}

private struct PopupAwareSearchField: NSViewRepresentable {
  @Binding var text: String
  let focusNonce: Int

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> PopupAwareNSSearchField {
    let field = PopupAwareNSSearchField()
    field.delegate = context.coordinator
    field.font = .systemFont(ofSize: 20)
    field.controlSize = .large
    field.focusRingType = .default
    field.sendsSearchStringImmediately = true
    field.stringValue = text
    context.coordinator.focus(field, nonce: focusNonce)
    return field
  }

  func updateNSView(_ field: PopupAwareNSSearchField, context: Context) {
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
      PerfTrace.mark("search.input", detail: ["length": "\(field.stringValue.count)"])
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

private final class PopupAwareNSSearchField: NSSearchField {}
