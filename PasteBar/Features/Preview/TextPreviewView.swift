import AppKit
import SwiftUI

struct TextPreviewView: View {
  @Environment(AppState.self) private var appState
  let item: ClipItem
  var showsHeader: Bool = true
  var showsMetrics: Bool = true
  var minEditorHeight: CGFloat = 44
  var maxEditorHeight: CGFloat = 260
  var expandsToFill: Bool = false
  var allowsScrolling: Bool = true

  @State private var draftText: String = ""
  @State private var isSyncingFromItem = false
  @State private var saveTask: Task<Void, Never>?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if showsHeader {
        HStack {
          if !item.label.isEmpty {
            Text(item.label)
              .font(.headline)
              .lineLimit(1)
          }
        }
      }

      TextEditor(text: $draftText)
        .font(.system(size: 14))
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity)
        .frame(
          minHeight: expandsToFill ? max(minEditorHeight, 180) : minEditorHeight,
          maxHeight: expandsToFill ? .infinity : maxEditorHeight,
          alignment: .topLeading
        )
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear { syncFromItem() }
        .onChange(of: item.id) { _, _ in syncFromItem() }
        .onChange(of: draftText) { _, newValue in handleDraftChange(newValue) }
        .onDisappear { handleDisappear() }

      if showsMetrics {
        HStack(spacing: 6) {
          Text("\(lineCount) lines")
          Text("·")
          Text("\(draftText.count) chars")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: expandsToFill ? .infinity : nil, alignment: .topLeading)
  }

  private func handleDraftChange(_ newValue: String) {
    guard !isSyncingFromItem else {
      return
    }

    saveTask?.cancel()
    saveTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else {
        return
      }
      appState.updateText(for: item.id, text: newValue)
    }
  }

  private func syncFromItem() {
    isSyncingFromItem = true
    draftText = item.content.text ?? ""
    DispatchQueue.main.async {
      isSyncingFromItem = false
    }
  }

  private func handleDisappear() {
    saveTask?.cancel()
    let current = item.content.text ?? ""
    guard draftText != current else {
      return
    }
    appState.updateText(for: item.id, text: draftText)
  }

  private var lineCount: Int {
    max(draftText.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
  }
}

struct AutoGrowingTextPreviewView: View {
  private static let placeholderCharacter = "\u{200B}"

  @Environment(AppState.self) private var appState
  let item: ClipItem

  @State private var draftText: String = ""
  @State private var isSyncingFromItem = false
  @State private var saveTask: Task<Void, Never>?

  var body: some View {
    TextField("", text: $draftText, axis: .vertical)
      .textFieldStyle(.plain)
      .font(.system(size: 14))
      .lineLimit(1...)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
      .background(Color(nsColor: .textBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .onAppear { syncFromItem() }
      .onChange(of: item.id) { _, _ in syncFromItem() }
      .onChange(of: draftText) { _, newValue in handleDraftChange(newValue) }
      .onDisappear { handleDisappear() }
      .onKeyPress(.return, phases: .down, action: handleReturn)
  }

  private func handleDraftChange(_ newValue: String) {
    guard !isSyncingFromItem else {
      return
    }

    saveTask?.cancel()
    saveTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else {
        return
      }
      appState.updateText(for: item.id, text: newValue)
    }
  }

  private func syncFromItem() {
    isSyncingFromItem = true
    draftText = item.content.text ?? ""
    DispatchQueue.main.async {
      isSyncingFromItem = false
    }
  }

  private func handleDisappear() {
    saveTask?.cancel()
    let current = item.content.text ?? ""
    guard draftText != current else {
      return
    }
    appState.updateText(for: item.id, text: draftText)
  }

  private func handleReturn(_ keyPress: KeyPress) -> KeyPress.Result {
    if keyPress.modifiers.contains(.option) || keyPress.modifiers.contains(.shift) {
      return .handled
    }
    guard keyPress.modifiers.isEmpty else {
      return .ignored
    }
    insertLineBreakWithWorkaround()
    return .handled
  }

  private func currentEditor() -> NSTextView? {
    NSApp.keyWindow?.firstResponder as? NSTextView
  }

  // 避开原生 return 插入换行时的瞬时重排抖动。
  private func insertLineBreakWithWorkaround() {
    guard let editor = currentEditor() else {
      return
    }

    editor.insertText(Self.placeholderCharacter, replacementRange: editor.selectedRange())

    DispatchQueue.main.async {
      guard let editor = currentEditor() else {
        return
      }

      editor.doCommand(by: #selector(NSResponder.insertLineBreak(_:)))

      DispatchQueue.main.async {
        guard let editor = currentEditor() else {
          return
        }

        removePlaceholderCharacter(from: editor)
        syncDraftTextPreservingSelection(from: editor)
      }
    }
  }

  private func removePlaceholderCharacter(from editor: NSTextView) {
    guard let textStorage = editor.textStorage else {
      return
    }

    let selection = editor.selectedRange()
    let nsString = textStorage.string as NSString
    let backwardRange = NSRange(location: 0, length: min(selection.location, nsString.length))
    var placeholderRange = nsString.range(
      of: Self.placeholderCharacter,
      options: .backwards,
      range: backwardRange
    )

    if placeholderRange.location == NSNotFound {
      let forwardRange = NSRange(
        location: min(selection.location, nsString.length),
        length: max(0, nsString.length - selection.location)
      )
      placeholderRange = nsString.range(
        of: Self.placeholderCharacter,
        options: [],
        range: forwardRange
      )
    }

    guard placeholderRange.location != NSNotFound else {
      return
    }

    textStorage.replaceCharacters(in: placeholderRange, with: "")
    let newLocation =
      placeholderRange.location < selection.location
      ? max(placeholderRange.location, selection.location - placeholderRange.length)
      : selection.location
    editor.setSelectedRange(NSRange(location: newLocation, length: selection.length))
  }

  private func syncDraftTextPreservingSelection(from editor: NSTextView) {
    let selection = editor.selectedRange()
    draftText = editor.string

    DispatchQueue.main.async {
      guard let editor = currentEditor() else {
        return
      }
      editor.setSelectedRange(selection)
    }
  }
}
