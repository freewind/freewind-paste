import AppKit
import SwiftUI

struct SyntaxHighlightingTextView: NSViewRepresentable {
  @Binding var text: String
  let language: String?
  let isEditable: Bool
  @Binding var measuredHeight: CGFloat
  let minHeight: CGFloat
  let maxHeight: CGFloat

  init(
    text: Binding<String>,
    language: String?,
    isEditable: Bool,
    measuredHeight: Binding<CGFloat>,
    minHeight: CGFloat = 44,
    maxHeight: CGFloat = 260
  ) {
    _text = text
    self.language = language
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
    let selectedRange = textView.selectedRange()
    if textView.string != text || textView.textStorage?.length == 0 {
      textView.textStorage?.setAttributedString(SyntaxTextHighlighter.highlight(text, language: language))
      if selectedRange.location <= textView.string.count {
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

enum SyntaxTextHighlighter {
  static func highlight(_ text: String, language: String?) -> NSAttributedString {
    let baseAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
      .foregroundColor: NSColor.textColor,
    ]
    let result = NSMutableAttributedString(string: text, attributes: baseAttributes)

    apply(pattern: #"(?m)//.*$|#.*$"#, color: .systemGreen, to: result)
    apply(pattern: #""([^"\\]|\\.)*""#, color: .systemRed, to: result)
    apply(pattern: #"\b\d+(\.\d+)?\b"#, color: .systemOrange, to: result)

    let keywords: [String] = switch language?.lowercased() {
    case "swift":
      ["struct", "class", "enum", "import", "let", "var", "func", "if", "guard", "return"]
    case "typescript", "javascript":
      ["const", "let", "function", "return", "if", "else", "import", "export", "class", "interface"]
    case "json":
      []
    case "python":
      ["def", "class", "import", "return", "if", "elif", "else", "for", "while"]
    default:
      ["SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE"]
    }

    if !keywords.isEmpty {
      let pattern = #"\b("# + keywords.joined(separator: "|") + #")\b"#
      apply(pattern: pattern, color: .systemBlue, to: result, options: [.caseInsensitive])
    }

    return result
  }

  private static func apply(
    pattern: String,
    color: NSColor,
    to result: NSMutableAttributedString,
    options: NSRegularExpression.Options = []
  ) {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
      return
    }
    let range = NSRange(location: 0, length: result.string.utf16.count)
    regex.matches(in: result.string, range: range).forEach { match in
      result.addAttributes([.foregroundColor: color], range: match.range)
    }
  }
}
