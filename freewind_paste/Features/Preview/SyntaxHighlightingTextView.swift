import AppKit
import SwiftUI

struct SyntaxHighlightingTextView: NSViewRepresentable {
  @Binding var text: String
  let identity: String
  let isEditable: Bool
  @Binding var measuredHeight: CGFloat
  let minHeight: CGFloat
  let maxHeight: CGFloat

  init(
    text: Binding<String>,
    identity: String,
    isEditable: Bool,
    measuredHeight: Binding<CGFloat>,
    minHeight: CGFloat = 44,
    maxHeight: CGFloat = 260
  ) {
    _text = text
    self.identity = identity
    self.isEditable = isEditable
    _measuredHeight = measuredHeight
    self.minHeight = minHeight
    self.maxHeight = maxHeight
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false

    let textView = NSTextView()
    textView.isRichText = false
    textView.allowsUndo = true
    textView.drawsBackground = false
    textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
    textView.delegate = context.coordinator
    textView.isEditable = isEditable
    textView.textContainerInset = NSSize(width: 10, height: 12)
    textView.isHorizontallyResizable = false
    textView.isVerticallyResizable = true
    textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.heightTracksTextView = false
    textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
    scrollView.documentView = textView
    update(textView: textView, scrollView: scrollView, coordinator: context.coordinator)
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else {
      return
    }
    textView.isEditable = isEditable
    update(textView: textView, scrollView: scrollView, coordinator: context.coordinator)
  }

  private func update(textView: NSTextView, scrollView: NSScrollView, coordinator: Coordinator) {
    let identityChanged = coordinator.lastIdentity != identity
    coordinator.lastIdentity = identity
    let selectedRange = textView.selectedRange()
    if identityChanged || textView.string != text || textView.textStorage?.length == 0 {
      textView.string = text
      if identityChanged {
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
      } else if selectedRange.location <= textView.string.count {
        textView.setSelectedRange(selectedRange)
      }
    }
    syncHeight(textView: textView, scrollView: scrollView, coordinator: coordinator)
  }

  private func syncHeight(textView: NSTextView, scrollView: NSScrollView, coordinator: Coordinator) {
    guard let textContainer = textView.textContainer else {
      return
    }

    let width = max(scrollView.contentSize.width, 1)
    textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
    textView.layoutManager?.ensureLayout(for: textContainer)

    let usedHeight = textView.layoutManager?.usedRect(for: textContainer).height ?? 0
    let contentHeight = ceil(usedHeight + textView.textContainerInset.height * 2)
    let nextHeight = min(max(contentHeight, minHeight), maxHeight)

    scrollView.hasVerticalScroller = contentHeight > maxHeight
    if abs(coordinator.lastHeight - nextHeight) > 0.5 {
      coordinator.lastHeight = nextHeight
      DispatchQueue.main.async {
        measuredHeight = nextHeight
      }
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: SyntaxHighlightingTextView
    var lastHeight: CGFloat = 44
    var lastIdentity: String?

    init(_ parent: SyntaxHighlightingTextView) {
      self.parent = parent
      lastHeight = parent.minHeight
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else {
        return
      }
      parent.text = textView.string
      if let scrollView = textView.enclosingScrollView {
        parent.syncHeight(textView: textView, scrollView: scrollView, coordinator: self)
      }
    }
  }
}
