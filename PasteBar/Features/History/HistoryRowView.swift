import AppKit

struct HistoryTableRowState: Equatable {
  let item: ClipItem
  let isSelected: Bool
  let isFocused: Bool
  let isChecked: Bool
  let showsFavorite: Bool
}

final class HistoryTableView: NSTableView {
  var onRowClick: ((Int, NSEvent.ModifierFlags) -> Void)?
  var onRowDoubleClick: ((Int) -> Void)?
  var onContextMenu: ((Int) -> Void)?
  var dragItemProvider: ((Int, NSEvent) -> NSDraggingItem?)?
  var onSpaceKey: (() -> Void)?

  private var mouseDownRow: Int?
  private var mouseDownPoint: NSPoint = .zero
  private var dragSessionStarted = false

  override var acceptsFirstResponder: Bool { true }

  override func mouseDown(with event: NSEvent) {
    let localPoint = convert(event.locationInWindow, from: nil)
    let row = row(at: localPoint)

    mouseDownRow = row >= 0 ? row : nil
    mouseDownPoint = localPoint
    dragSessionStarted = false

    guard row >= 0 else {
      super.mouseDown(with: event)
      return
    }

    window?.makeFirstResponder(self)
    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    onRowClick?(row, modifiers)

    if event.clickCount == 2 {
      onRowDoubleClick?(row)
    }
  }

  override func mouseDragged(with event: NSEvent) {
    guard
      !dragSessionStarted,
      let row = mouseDownRow,
      row >= 0
    else {
      return
    }

    let currentPoint = convert(event.locationInWindow, from: nil)
    if abs(currentPoint.x - mouseDownPoint.x) < 3, abs(currentPoint.y - mouseDownPoint.y) < 3 {
      return
    }

    guard let draggingItem = dragItemProvider?(row, event) else {
      return
    }

    dragSessionStarted = true
    beginDraggingSession(with: [draggingItem], event: event, source: self)
  }

  override func mouseUp(with event: NSEvent) {
    mouseDownRow = nil
    dragSessionStarted = false
  }

  override func menu(for event: NSEvent) -> NSMenu? {
    let localPoint = convert(event.locationInWindow, from: nil)
    let row = row(at: localPoint)
    if row >= 0 {
      window?.makeFirstResponder(self)
      onContextMenu?(row)
      return menu
    }
    return nil
  }

  override func keyDown(with event: NSEvent) {
    switch event.keyCode {
    case 49:
      onSpaceKey?()
    default:
      super.keyDown(with: event)
    }
  }

  override func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
    .move
  }

  override func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }
}

final class HistoryTableRowView: NSTableRowView {
  private var rowState: HistoryTableRowState?

  override var isEmphasized: Bool {
    get { false }
    set { }
  }

  func apply(_ rowState: HistoryTableRowState) {
    self.rowState = rowState
    needsDisplay = true
  }

  override func drawSelection(in dirtyRect: NSRect) {}

  override func drawBackground(in dirtyRect: NSRect) {
    guard let rowState else {
      return
    }

    let color: NSColor
    if rowState.isFocused {
      color = .controlAccentColor.withAlphaComponent(0.18)
    } else if rowState.isSelected {
      color = .controlAccentColor.withAlphaComponent(0.10)
    } else {
      color = .clear
    }

    color.setFill()
    dirtyRect.fill()
  }
}

final class HistoryCheckCellView: NSTableCellView {
  private let button = HistoryIconButton()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    button.translatesAutoresizingMaskIntoConstraints = false
    addSubview(button)
    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: centerXAnchor),
      button.centerYAnchor.constraint(equalTo: centerYAnchor),
      button.widthAnchor.constraint(equalToConstant: 14),
      button.heightAnchor.constraint(equalToConstant: 14)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(rowState: HistoryTableRowState, onToggle: @escaping () -> Void) {
    button.image = NSImage(
      systemSymbolName: rowState.isChecked ? "checkmark.square.fill" : "square",
      accessibilityDescription: nil
    )
    button.contentTintColor = rowState.isChecked ? .controlAccentColor : .secondaryLabelColor
    button.onPress = onToggle
  }
}

final class HistoryFavoriteCellView: NSTableCellView {
  private let button = HistoryIconButton()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    button.translatesAutoresizingMaskIntoConstraints = false
    addSubview(button)
    NSLayoutConstraint.activate([
      button.centerXAnchor.constraint(equalTo: centerXAnchor),
      button.centerYAnchor.constraint(equalTo: centerYAnchor),
      button.widthAnchor.constraint(equalToConstant: 14),
      button.heightAnchor.constraint(equalToConstant: 14)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(rowState: HistoryTableRowState, onToggle: @escaping () -> Void) {
    if rowState.showsFavorite {
      button.isHidden = false
      button.image = NSImage(
        systemSymbolName: rowState.item.favorite ? "star.fill" : "star",
        accessibilityDescription: nil
      )
      button.contentTintColor = rowState.item.favorite ? .systemYellow : .secondaryLabelColor
      button.alphaValue = rowState.item.favorite ? 1 : 0.55
      button.onPress = onToggle
    } else {
      button.isHidden = true
      button.onPress = nil
    }
  }
}

final class HistoryContentCellView: NSTableCellView {
  private let stackView = NSStackView()
  private let badgeContainer = NSView()
  private let badgeLabel = NSTextField(labelWithString: "")
  private let titleLabel = NSTextField(labelWithString: "")

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    stackView.orientation = .horizontal
    stackView.alignment = .centerY
    stackView.spacing = 6
    stackView.translatesAutoresizingMaskIntoConstraints = false

    badgeContainer.wantsLayer = true
    badgeContainer.layer?.cornerRadius = 8
    badgeContainer.layer?.backgroundColor = NSColor.secondaryLabelColor.withAlphaComponent(0.12).cgColor
    badgeContainer.translatesAutoresizingMaskIntoConstraints = false

    badgeLabel.font = .systemFont(ofSize: 10, weight: .semibold)
    badgeLabel.textColor = .secondaryLabelColor
    badgeLabel.translatesAutoresizingMaskIntoConstraints = false

    titleLabel.font = .systemFont(ofSize: 12)
    titleLabel.lineBreakMode = .byTruncatingTail
    titleLabel.maximumNumberOfLines = 1
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    addSubview(stackView)
    badgeContainer.addSubview(badgeLabel)
    stackView.addArrangedSubview(badgeContainer)
    stackView.addArrangedSubview(titleLabel)

    NSLayoutConstraint.activate([
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
      badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 6),
      badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -6),
      badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 1),
      badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -1)
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func configure(rowState: HistoryTableRowState) {
    let item = rowState.item
    let label = item.label.trimmingCharacters(in: .whitespacesAndNewlines)

    badgeContainer.isHidden = label.isEmpty
    badgeLabel.stringValue = label
    titleLabel.stringValue = item.listRowTitle
    titleLabel.textColor = item.listRowTextColor
  }
}

private final class HistoryIconButton: NSButton {
  var onPress: (() -> Void)?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    bezelStyle = .regularSquare
    isBordered = false
    imagePosition = .imageOnly
    setButtonType(.momentaryChange)
    target = self
    action = #selector(handlePress)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  @objc
  private func handlePress() {
    window?.makeFirstResponder(enclosingHistoryTableView)
    onPress?()
  }
}

private extension NSView {
  var enclosingHistoryTableView: HistoryTableView? {
    var current: NSView? = self
    while let view = current {
      if let tableView = view as? HistoryTableView {
        return tableView
      }
      current = view.superview
    }
    return nil
  }
}

private extension ClipItem {
  var listRowTitle: String {
    switch kind {
    case .text:
      let preview = normalizedTextPreview
      return preview.isEmpty ? "Text" : preview
    case .image:
      if let width = meta.imageWidth, let height = meta.imageHeight {
        return "Image \(width)x\(height)"
      }
      return "Image"
    case .file:
      if let count = meta.fileCount, count > 1 {
        return "\(meta.fileName ?? "Files") +\(count - 1)"
      }
      return meta.fileName ?? "File"
    }
  }

  var listRowTextColor: NSColor {
    switch DateGroup.title(for: groupingDate) {
    case "Today":
      return .labelColor
    case "Yesterday":
      return .labelColor.withAlphaComponent(0.82)
    default:
      return .labelColor.withAlphaComponent(0.64)
    }
  }
}
