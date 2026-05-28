import SwiftUI

#if DEBUG
import FreewindSwiftUIDebugBridge

extension View {
  @ViewBuilder
  func pasteDebugNode(
    id: String,
    role: String,
    label: String,
    actions: [String] = []
  ) -> some View {
    debugNode(id: id, role: role, label: label, actions: actions)
  }
}
#else
extension View {
  @ViewBuilder
  func pasteDebugNode(
    id: String,
    role: String,
    label: String,
    actions: [String] = []
  ) -> some View {
    self
  }
}
#endif
