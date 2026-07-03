import SwiftUI

private struct DebugActionRegistrationModifier: ViewModifier {
    let id: String
    let action: String
    let args: [String]
    let perform: @MainActor (DebugActionRequest) -> DebugActionResponse

    @Environment(DebugRegistry.self) private var registry
    @State private var token: DebugRegistry.RegistrationToken?

    private var registrationKey: String {
        ([id, action] + args).joined(separator: "::")
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                register()
            }
            .onChange(of: registrationKey) { _, _ in
                unregister()
                register()
            }
            .onDisappear {
                unregister()
            }
    }

    private func register() {
        guard token == nil else {
            return
        }
        token = registry.registerNodeAction(
            id: id,
            action: action,
            args: args,
            perform: perform
        )
    }

    private func unregister() {
        token?.cancel()
        token = nil
    }
}

public extension View {
    func debugAction(
        id: String,
        action: String,
        args: [String] = [],
        perform: @escaping @MainActor () -> Void
    ) -> some View {
        modifier(
            DebugActionRegistrationModifier(
                id: id,
                action: action,
                args: args,
                perform: { _ in
                    perform()
                    return .ok("action handled")
                }
            )
        )
    }

    func debugAction(
        id: String,
        action: String,
        args: [String] = [],
        perform: @escaping @MainActor (DebugActionRequest) -> DebugActionResponse
    ) -> some View {
        modifier(
            DebugActionRegistrationModifier(
                id: id,
                action: action,
                args: args,
                perform: perform
            )
        )
    }
}
