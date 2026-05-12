import SwiftUI

struct SearchBarView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: ClipStore
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("Search", text: $store.searchQuery)
      .textFieldStyle(.roundedBorder)
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
  }
}
