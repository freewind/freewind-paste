import SwiftUI

struct SearchBarView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("Search", text: $store.searchQuery)
      .textFieldStyle(.roundedBorder)
      .font(.system(size: 18))
      .controlSize(.large)
      .frame(height: 38)
      .focused($isFocused)
      .onAppear {
        isFocused = true
      }
      .onChange(of: appState.searchFocusNonce) { _, _ in
        isFocused = true
      }
      .onChange(of: store.searchQuery) { _, _ in
        store.selectFirstVisible()
      }
      .onSubmit {
        appState.pasteSelection(mode: .normalEnter)
      }
      .onMoveCommand { direction in
        switch direction {
        case .up:
          store.moveFocus(by: -1)
        case .down:
          store.moveFocus(by: 1)
        default:
          break
        }
      }
  }
}
