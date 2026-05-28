import Foundation

#if DEBUG
import FreewindSwiftUIDebugBridge
#endif

@MainActor
enum PerfTrace {
  #if DEBUG
  static weak var bridge: DebugBridge?
  static var lastMetrics: [String: String] = [:]
  private static let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".freewind_paste/perf.log")
  private static var pendingLines: [String] = []
  private static var flushScheduled = false
  private static var tableUpdateLastLog = CFAbsoluteTimeGetCurrent()
  #endif

  static func measure(_ name: String, detail: [String: String] = [:], _ work: () -> Void) {
    #if DEBUG
    let start = CFAbsoluteTimeGetCurrent()
    work()
    log(name: name, ms: (CFAbsoluteTimeGetCurrent() - start) * 1000, detail: detail)
    #else
    work()
    #endif
  }

  static func measureReturning<T>(
    _ name: String,
    detail: [String: String] = [:],
    _ work: () -> T
  ) -> T {
    #if DEBUG
    let start = CFAbsoluteTimeGetCurrent()
    let value = work()
    var merged = detail
    if let count = value as? Int {
      merged["count"] = "\(count)"
    } else if let items = value as? [Any] {
      merged["count"] = "\(items.count)"
    }
    log(name: name, ms: (CFAbsoluteTimeGetCurrent() - start) * 1000, detail: merged)
    return value
    #else
    return work()
    #endif
  }

  static func mark(_ name: String, detail: [String: String] = [:]) {
    #if DEBUG
    log(name: name, ms: 0, detail: detail)
    #endif
  }

  #if DEBUG
  private static func log(name: String, ms: Double, detail: [String: String]) {
    if name == "table.update" {
      let now = CFAbsoluteTimeGetCurrent()
      guard now - tableUpdateLastLog >= 0.25 else {
        return
      }
      tableUpdateLastLog = now
    }

    let msText = String(format: "%.2f", ms)
    var data = detail
    data["ms"] = msText
    data["name"] = name

    lastMetrics[name] = msText
    lastMetrics["lastEvent"] = name
    lastMetrics["lastMs"] = msText

    bridge?.log(
      event: "perf",
      level: "info",
      source: "perf",
      summary: "\(name) \(msText)ms",
      data: data
    )

    enqueueFileLine("\(ISO8601DateFormatter().string(from: .now)) \(name) \(msText)ms \(formatDetail(data))")
  }

  static func clearFileLog() {
    try? FileManager.default.createDirectory(
      at: logURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? Data().write(to: logURL)
    pendingLines.removeAll(keepingCapacity: true)
  }

  private static func enqueueFileLine(_ line: String) {
    pendingLines.append(line)
    scheduleFlushIfNeeded()
  }

  private static func scheduleFlushIfNeeded() {
    guard !flushScheduled else {
      return
    }
    flushScheduled = true
    let lines = pendingLines
    pendingLines.removeAll(keepingCapacity: true)
    DispatchQueue.global(qos: .utility).async {
      appendFileLines(lines)
      Task { @MainActor in
        flushScheduled = false
        if !pendingLines.isEmpty {
          scheduleFlushIfNeeded()
        }
      }
    }
  }

  private static func appendFileLines(_ lines: [String]) {
    guard !lines.isEmpty else {
      return
    }
    let directory = logURL.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let payload = lines.joined(separator: "\n") + "\n"
    guard let data = payload.data(using: .utf8) else {
      return
    }
    if FileManager.default.fileExists(atPath: logURL.path) {
      if let handle = try? FileHandle(forWritingTo: logURL) {
        defer { try? handle.close() }
        try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
      }
    } else {
      try? data.write(to: logURL)
    }
  }

  private static func formatDetail(_ detail: [String: String]) -> String {
    detail
      .sorted { $0.key < $1.key }
      .map { "\($0.key)=\($0.value)" }
      .joined(separator: " ")
  }
  #endif
}
