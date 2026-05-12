import SwiftUI

struct SearchBarView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var uiState: ClipViewState
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("Search", text: $uiState.searchQuery)
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
      .onChange(of: uiState.searchQuery) { _, _ in
        uiState.selectFirstVisible()
      }
      .onSubmit {
        appState.pasteSelection(mode: .normalEnter)
      }
      .onMoveCommand { direction in
        switch direction {
        case .up:
          uiState.moveFocus(by: -1)
        case .down:
          uiState.moveFocus(by: 1)
        default:
          break
        }
      }
  }
}
