import Foundation

enum LanguageGuessService {
  static func guess(for text: String) -> String? {
    let source = text.lowercased()

    if source.contains("import swiftui") || source.contains("let package = package(") {
      return "swift"
    }
    if source.contains("function ") || source.contains("const ") || source.contains("=>") {
      return source.contains("interface ") || source.contains(": string") ? "typescript" : "javascript"
    }
    if source.contains("{") && source.contains("}") && source.contains(":") && source.contains("\"") {
      return "json"
    }
    if source.contains("def ") || source.contains("import os") {
      return "python"
    }
    if source.contains("<html") || source.contains("</div>") {
      return "html"
    }
    if source.contains("SELECT ") || source.contains("FROM ") || source.contains("where ") {
      return "sql"
    }
    if source.contains("package main") || source.contains("func main()") {
      return "go"
    }

    return nil
  }
}
