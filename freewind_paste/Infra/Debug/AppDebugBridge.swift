#if DEBUG
import Foundation
import FreewindSwiftUIDebugBridge

@MainActor
enum AppDebugBridge {
  private static let port: UInt16 = 7880
  private static var didSetup = false
  private static var registrationTokens: [DebugRegistry.RegistrationToken] = []

  static func setup(appState: AppState) {
    guard !didSetup else {
      return
    }
    didSetup = true

    let bridge = appState.debugBridge
    PerfTrace.bridge = bridge
    PerfTrace.clearFileLog()

    registrationTokens.append(
      bridge.registerIntent(name: "show_popup") { _ in
        appState.showPopup()
        return .ok("popup shown")
      }
    )

    registrationTokens.append(
      bridge.registerIntent(name: "hide_popup") { _ in
        appState.hidePopup()
        return .ok("popup hidden")
      }
    )

    registrationTokens.append(
      bridge.registerIntent(name: "clear_perf_logs") { _ in
        _ = bridge.registry.clearLogs()
        PerfTrace.clearFileLog()
        return .ok("perf logs cleared")
      }
    )

    registrationTokens.append(
      bridge.registerIntent(name: "benchmark_search") { _ in
        runSearchBenchmark(appState: appState)
      }
    )

    registrationTokens.append(
      bridge.registerIntent(name: "set_search", args: ["text"]) { request in
        let text = request.args?["text"] ?? request.text ?? ""
        appState.uiState.searchQuery = text
        return .ok("search set to '\(text)'")
      }
    )

    registrationTokens.append(
      bridge.registerNodeAction(id: "search_field", action: "set", args: ["text"]) { request in
        let text = request.args?["text"] ?? request.text ?? "test"
        appState.uiState.searchQuery = text
        return .ok("search set to '\(text)'")
      }
    )

    bridge.start(
      port: port,
      screenName: { appState.isPopupVisible ? "PopupScreen" : "Background" }
    ) {
      publishAppState(appState)
    }

    bridge.log(
      event: "debug_bridge.ready",
      source: "system",
      summary: "Debug bridge listening",
      data: [
        "port": "\(port)",
        "perfLog": perfLogPath,
      ]
    )
  }

  private static var perfLogPath: String {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".freewind_paste/perf.log")
      .path
  }

  private static func publishAppState(_ appState: AppState) -> [String: String] {
    let uiState = appState.uiState
    var state: [String: String] = [
      "debugStatus": appState.debugBridge.statusMessage,
      "isPopupVisible": appState.isPopupVisible ? "true" : "false",
      "searchQuery": uiState.searchQuery,
      "storeItemCount": "\(appState.store.items.count)",
      "visibleItemCount": "\(uiState.visibleItems.count)",
      "expandedMatchCount": "\(uiState.expandedSearchMatchedIDs.count)",
      "currentTab": uiState.currentTab.rawValue,
      "kindFilter": uiState.kindFilter.rawValue,
      "perfLogPath": perfLogPath,
    ]

    for (key, value) in PerfTrace.lastMetrics {
      state["perf.\(key)"] = value
    }

    appState.debugBridge.publishTargetState(
      id: "search_field",
      state: [
        "query": uiState.searchQuery,
        "visibleItemCount": "\(uiState.visibleItems.count)",
      ]
    )

    return state
  }

  private static func runSearchBenchmark(appState: AppState) -> DebugActionResponse {
    if !appState.isPopupVisible {
      appState.showPopup()
    }

    let queries = ["", "a", "ab", "test", "json", "swift", "http"]
    var lines: [String] = []

    for query in queries {
      PerfTrace.measure("benchmark.set_search", detail: ["query": query]) {
        appState.uiState.searchQuery = query
      }
      let count = appState.uiState.visibleItems.count
      lines.append("\(query.isEmpty ? "<empty>" : query): \(count) visible")
    }

    appState.uiState.searchQuery = ""
    return .ok(lines.joined(separator: "; "))
  }
}
#endif
