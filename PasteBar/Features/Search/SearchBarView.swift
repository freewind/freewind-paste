import SwiftUI

struct SearchBarView: View {
  @EnvironmentObject private var store: ClipStore

  var body: some View {
    TextField("Search", text: $store.searchQuery)
      .textFieldStyle(.roundedBorder)
  }
}
