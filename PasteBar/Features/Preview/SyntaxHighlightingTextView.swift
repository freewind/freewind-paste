import AppKit
import SwiftUI

struct SyntaxHighlightingTextView: NSViewRepresentable {
  @Binding var text: String
  let language: String?
  let isEditable: Bool

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
    scrollView.documentView = textView
    update(textView: textView)
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView else {
      return
    }
    textView.isEditable = isEditable
    update(textView: textView)
  }

  private func update(textView: NSTextView) {
    let selectedRange = textView.selectedRange()
    if textView.string != text || textView.textStorage?.length == 0 {
      textView.textStorage?.setAttributedString(SyntaxTextHighlighter.highlight(text, language: language))
      if selectedRange.location <= textView.string.count {
        textView.setSelectedRange(selectedRange)
      }
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: SyntaxHighlightingTextView

    init(_ parent: SyntaxHighlightingTextView) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else {
        return
      }
      parent.text = textView.string
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
