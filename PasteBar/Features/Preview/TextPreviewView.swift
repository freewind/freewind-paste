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
  @State private var editorHeight: CGFloat = 44

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

      AutoSizingEditableTextView(
        text: $draftText,
        identity: item.id,
        measuredHeight: $editorHeight,
        minHeight: minEditorHeight,
        maxHeight: maxEditorHeight,
        allowsScrolling: allowsScrolling
      )
      .frame(maxWidth: .infinity)
      .frame(
        minHeight: expandsToFill ? max(editorHeight, minEditorHeight) : editorHeight,
        maxHeight: expandsToFill ? .infinity : editorHeight,
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

private struct AutoSizingEditableTextView: NSViewRepresentable {
  @Binding var text: String
  let identity: String
  @Binding var measuredHeight: CGFloat
  let minHeight: CGFloat
  let maxHeight: CGFloat
  let allowsScrolling: Bool

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.drawsBackground = false
    scrollView.borderType = .noBorder
    scrollView.hasVerticalScroller = false
    scrollView.hasHorizontalScroller = false
    scrollView.autohidesScrollers = true

    let textView = NSTextView()
    textView.isRichText = false
    textView.allowsUndo = true
    textView.drawsBackground = false
    textView.isEditable = true
    textView.isSelectable = true
    textView.font = .systemFont(ofSize: 14)
    textView.textColor = .textColor
    textView.delegate = context.coordinator
    textView.textContainerInset = NSSize(width: 10, height: 12)
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.lineFragmentPadding = 0

    scrollView.documentView = textView
    context.coordinator.apply(text: text, to: textView, resetSelection: true)
    context.coordinator.syncHeight(textView: textView, scrollView: scrollView)
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else {
      return
    }

    let identityChanged = context.coordinator.lastIdentity != identity
    context.coordinator.lastIdentity = identity

    if identityChanged || textView.string != text {
      context.coordinator.apply(text: text, to: textView, resetSelection: identityChanged)
    }

    context.coordinator.syncHeight(textView: textView, scrollView: scrollView)
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    private let parent: AutoSizingEditableTextView
    var lastIdentity: String?
    private var lastHeight: CGFloat

    init(_ parent: AutoSizingEditableTextView) {
      self.parent = parent
      lastHeight = parent.minHeight
      lastIdentity = parent.identity
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else {
        return
      }

      parent.text = textView.string
      if let scrollView = textView.enclosingScrollView {
        syncHeight(textView: textView, scrollView: scrollView)
      }
    }

    func apply(text: String, to textView: NSTextView, resetSelection: Bool) {
      let selectedRange = textView.selectedRange()
      let attributedText = NSAttributedString(string: text, attributes: textAttributes)
      textView.textStorage?.setAttributedString(attributedText)
      textView.typingAttributes = textAttributes

      if resetSelection {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.enclosingScrollView?.contentView.scroll(to: .zero)
        if let scrollView = textView.enclosingScrollView {
          scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        return
      }

      let safeLocation = min(selectedRange.location, textView.string.count)
      let safeLength = min(selectedRange.length, textView.string.count - safeLocation)
      textView.setSelectedRange(NSRange(location: safeLocation, length: safeLength))
    }

    func syncHeight(textView: NSTextView, scrollView: NSScrollView) {
      guard let textContainer = textView.textContainer else {
        return
      }

      let width = max(scrollView.contentSize.width, 1)
      textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
      textView.layoutManager?.ensureLayout(for: textContainer)

      let usedHeight = textView.layoutManager?.usedRect(for: textContainer).height ?? 0
      let contentHeight = ceil(usedHeight + textView.textContainerInset.height * 2)
      let nextHeight = min(max(contentHeight, parent.minHeight), parent.maxHeight)

      scrollView.hasVerticalScroller = parent.allowsScrolling && contentHeight > parent.maxHeight
      if abs(lastHeight - nextHeight) > 0.5 {
        lastHeight = nextHeight
        parent.measuredHeight = nextHeight
      }
    }

    private var textAttributes: [NSAttributedString.Key: Any] {
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.lineSpacing = 4
      paragraphStyle.lineBreakMode = .byWordWrapping
      return [
        .font: NSFont.systemFont(ofSize: 14),
        .foregroundColor: NSColor.textColor,
        .paragraphStyle: paragraphStyle
      ]
    }
  }
}
