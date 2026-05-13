import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
enum AppPaths {
  static let persistence = ClipPersistence()
  static let assetsDirectoryURL = persistence.assetsURL.appendingPathComponent("images", isDirectory: true)
}

@MainActor
@Observable
final class AppState {
  @ObservationIgnored let store: ClipStore
  @ObservationIgnored let uiState: ClipViewState

  var settings: AppSettings
  var statusMessage: String
  var isPopupVisible: Bool
  var searchFocusNonce: Int
  var imageOutputMode: ImageOutputMode
  var imageLowResMaxDimension: Double
  var accessibilityGranted: Bool

  @ObservationIgnored let repository: ClipRepository
  @ObservationIgnored let imageAssetStore: ImageAssetStore
  @ObservationIgnored let captureService: ClipboardCaptureService
  @ObservationIgnored let pasteService: ClipboardPasteService
  @ObservationIgnored private let workflow: ClipWorkflowService
  @ObservationIgnored private let accessibilityAccess: AccessibilityPasteTrigger
  @ObservationIgnored private let hotkeyService: HotkeyService
  @ObservationIgnored private let launchAtLoginService: LaunchAtLoginService
  @ObservationIgnored let popupController: PopupWindowController
  @ObservationIgnored private let transientImagePreviewController: TransientImagePreviewController
  @ObservationIgnored private let settingsWindowController: SettingsWindowController
  @ObservationIgnored private let menuBarController: MenuBarController

  @ObservationIgnored private var isBootstrapped = false
  @ObservationIgnored private var pasteTargetApp: NSRunningApplication?

  init(
    persistence: ClipPersistence? = nil,
    accessibilityAccess: AccessibilityPasteTrigger? = nil,
    hotkeyService: HotkeyService? = nil,
    launchAtLoginService: LaunchAtLoginService? = nil,
    popupController: PopupWindowController? = nil,
    transientImagePreviewController: TransientImagePreviewController? = nil,
    settingsWindowController: SettingsWindowController? = nil,
    menuBarController: MenuBarController? = nil
  ) {
    let persistence = persistence ?? AppPaths.persistence
    let accessibilityAccess = accessibilityAccess ?? AccessibilityPasteTrigger()
    let hotkeyService = hotkeyService ?? HotkeyService()
    let launchAtLoginService = launchAtLoginService ?? LaunchAtLoginService()
    let popupController = popupController ?? PopupWindowController()
    let transientImagePreviewController = transientImagePreviewController ?? TransientImagePreviewController()
    let settingsWindowController = settingsWindowController ?? SettingsWindowController()
    let menuBarController = menuBarController ?? MenuBarController()

    imageAssetStore = ImageAssetStore(assetsDirectoryURL: AppPaths.assetsDirectoryURL)
    repository = ClipRepository(
      persistence: persistence,
      imageAssetStore: imageAssetStore
    )
    let parser = ClipboardParseService(imageAssetStore: imageAssetStore)
    captureService = ClipboardCaptureService(parser: parser)
    pasteService = ClipboardPasteService(trigger: accessibilityAccess)
    self.accessibilityAccess = accessibilityAccess
    self.hotkeyService = hotkeyService
    self.launchAtLoginService = launchAtLoginService
    self.popupController = popupController
    self.transientImagePreviewController = transientImagePreviewController
    self.settingsWindowController = settingsWindowController
    self.menuBarController = menuBarController

    let loadedSettings = repository.loadSettings()
    settings = loadedSettings
    store = ClipStore(items: repository.loadItems())
    uiState = ClipViewState(store: store)
    workflow = ClipWorkflowService(
      store: store,
      uiState: uiState,
      repository: repository,
      pasteService: pasteService
    )
    statusMessage = "Ready"
    isPopupVisible = false
    searchFocusNonce = 0
    imageOutputMode = .original
    imageLowResMaxDimension = 512
    accessibilityGranted = accessibilityAccess.isPermissionGranted()
    workflow.pruneStaleItems()
    workflow.bootstrap()
  }

  func bootstrapIfNeeded() {
    bootstrap()
  }

  func bootstrap() {
    guard !isBootstrapped else {
      return
    }
    isBootstrapped = true

    menuBarController.install(
      onOpen: { [weak self] in
        Task { @MainActor [weak self] in
          self?.showPopup()
        }
      },
      onSettings: { [weak self] in
        Task { @MainActor [weak self] in
          self?.openSettings()
        }
      },
      onQuit: {
        NSApplication.shared.terminate(nil)
      }
    )

    registerHotkey()
    syncLaunchAtLogin()

    captureService.start { [weak self] item in
      Task { @MainActor [weak self] in
        self?.workflow.capture(item, preserveCurrentSelection: self?.isPopupVisible == true)
        self?.statusMessage = "Captured \(item.kind.rawValue)"
      }
    }

    showPopup()
  }

  func showPopup() {
    capturePasteTargetApp()
    uiState.selectFirstVisible()
    searchFocusNonce += 1
    popupController.show(with: self)
  }

  func activatePopup() {
    if isPopupVisible {
      popupController.show(with: self)
      return
    }
    showPopup()
  }

  func hidePopup() {
    popupController.hide()
    isPopupVisible = false
  }

  func openSettings() {
    refreshAccessibilityStatus()
    settingsWindowController.show(with: self)
  }

  func promptForLabel(for id: String) {
    let alert = NSAlert()
    alert.messageText = "Label"
    alert.informativeText = "Set a short label for this item."
    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Cancel")

    let field = NSTextField(string: workflow.labelValue(for: id))
    field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
    alert.accessoryView = field

    if alert.runModal() == .alertFirstButtonReturn {
      workflow.updateLabel(for: id, label: field.stringValue)
    }
  }

  func pasteSelection(mode: PasteMode) {
    if let message = workflow.pasteSelection(
      mode: mode,
      imageOutputMode: imageOutputMode,
      imageMaxDimension: imageLowResMaxDimension,
      targetApplication: pasteTargetApp
    ) {
      handlePasteResult(message)
    }
  }

  func paste(_ ids: Set<String>, mode: PasteMode) {
    if let message = workflow.paste(
      ids: ids,
      mode: mode,
      imageOutputMode: imageOutputMode,
      imageMaxDimension: imageLowResMaxDimension,
      targetApplication: pasteTargetApp
    ) {
      handlePasteResult(message)
    }
  }

  func deleteSelection(permanently: Bool) {
    delete(uiState.selectedIDs, permanently: permanently)
  }

  func deleteCheckedVisible(permanently: Bool) {
    delete(Set(uiState.checkedVisibleItems.map(\.id)), permanently: permanently)
  }

  func delete(_ ids: Set<String>, permanently: Bool) {
    workflow.delete(ids, permanently: permanently)
    statusMessage = permanently ? "Deleted permanently" : "Moved to trash"
  }

  func restoreSelection() {
    restore(uiState.selectedIDs)
  }

  func restore(_ id: String) {
    restore(Set([id]))
  }

  func restore(_ ids: Set<String>) {
    workflow.restore(ids)
    statusMessage = "Restored"
  }

  func updateSettings(_ mutate: (inout AppSettings) -> Void) {
    mutate(&settings)
    repository.saveSettings(settings)
    registerHotkey()
    syncLaunchAtLogin()
  }

  func clearAll() {
    workflow.clearAll()
    statusMessage = "Cleared"
  }

  func copyLowResolutionImage(from item: ClipItem) {
    if workflow.copyLowResolutionImage(from: item, imageMaxDimension: imageLowResMaxDimension) {
      statusMessage = "Copied low-res image"
    }
  }

  func previewImage(_ item: ClipItem) {
    guard
      item.kind == .image,
      let path = item.content.imageAssetPath,
      let image = imageAssetStore.load(
        relativePath: path,
        mode: imageOutputMode,
        maxDimension: imageLowResMaxDimension
      )
    else {
      statusMessage = "Image missing"
      return
    }

    transientImagePreviewController.show(
      image: image,
      title: item.titleText
    )
  }

  func openItemResource(_ item: ClipItem) {
    guard let url = primaryResourceURL(for: item) else {
      statusMessage = "File missing"
      return
    }
    NSWorkspace.shared.open(url)
  }

  func revealItemResource(_ item: ClipItem) {
    guard let url = primaryResourceURL(for: item) else {
      statusMessage = "File missing"
      return
    }
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func saveItemAs(_ item: ClipItem) {
    switch item.kind {
    case .image:
      saveImageItemAs(item)
    case .file:
      saveFileItemAs(item)
    case .text:
      break
    }
  }

  func moveItems(within sectionIDs: [String], from offsets: IndexSet, to destination: Int) {
    workflow.moveItems(within: sectionIDs, from: offsets, to: destination)
  }

  func reverseSelection() {
    workflow.reverseSelection()
  }

  func toggleFavorite(for id: String) {
    workflow.toggleFavorite(for: id)
  }

  func setFavorite(_ ids: Set<String>, favorite: Bool) {
    workflow.setFavorite(ids, favorite: favorite)
  }

  func updateText(for id: String, text: String) {
    workflow.updateText(
      for: id,
      text: text,
      languageGuess: LanguageGuessService.guess(for: text)
    )
  }

  func requestAccessibilityPermission() {
    _ = accessibilityAccess.requestPermissionIfNeeded()
    refreshAccessibilityStatus()
  }

  func openAccessibilitySettings() {
    accessibilityAccess.openSettings()
  }

  func refreshAccessibilityStatus() {
    accessibilityGranted = accessibilityAccess.isPermissionGranted()
  }

  func handlePopupKeyDown(_ event: NSEvent) -> NSEvent? {
    guard
      isPopupVisible,
      event.window === popupController.currentWindow,
      event.type == .keyDown
    else {
      return event
    }

    guard let action = popupShortcutAction(for: event) else {
      return event
    }

    if shouldBypassPopupShortcut(action) {
      return event
    }

    switch action {
    case .closePopup:
      if uiState.collapseSelectionToAnchor() {
        return nil
      }
      hidePopup()
    case .focusList:
      popupController.focusHistoryList()
    case .paste:
      pasteSelection(mode: .normalEnter)
    case .nativePaste:
      pasteSelection(mode: .nativeShiftEnter)
    case .focusPrevious:
      uiState.moveFocus(by: -1)
    case .focusNext:
      uiState.moveFocus(by: 1)
    case .expandPrevious:
      uiState.moveFocusExtendingSelection(by: -1)
    case .expandNext:
      uiState.moveFocusExtendingSelection(by: 1)
    case .pageUp:
      uiState.requestViewportMove(.page(direction: -1))
    case .pageDown:
      uiState.requestViewportMove(.page(direction: 1))
    case .jumpToTop:
      uiState.requestViewportMove(.boundary(isStart: true))
    case .jumpToBottom:
      uiState.requestViewportMove(.boundary(isStart: false))
    case .moveSelectionUp:
      moveSelectionBlock(by: -1)
    case .moveSelectionDown:
      moveSelectionBlock(by: 1)
    case .deleteSelection:
      if shouldBypassDeleteShortcut() {
        return event
      }
      deleteSelection(permanently: uiState.currentTab == .trash)
    case .deleteSelectionPermanently:
      if shouldBypassDeleteShortcut() {
        return event
      }
      deleteSelection(permanently: true)
    }
    return nil
  }

  func handlePopupMouseDown(_ event: NSEvent) -> NSEvent? {
    guard
      isPopupVisible,
      event.window === popupController.currentWindow,
      event.type == .leftMouseDown
    else {
      return event
    }

    popupController.activateHistoryListIfNeeded(for: event)
    return event
  }

  func moveSelectionShortcut(by offset: Int) {
    moveSelectionBlock(by: offset)
  }

  private func handlePasteResult(_ message: String) {
    statusMessage = message
    if message.hasPrefix("Pasted") || message.hasPrefix("Native pasted") {
      hidePopup()
    }
  }

  private func shouldBypassDeleteShortcut() -> Bool {
    guard let responder = popupController.currentWindow?.firstResponder as? NSTextView else {
      return false
    }

    if responder.isFieldEditor {
      return !uiState.searchQuery.isEmpty
    }

    return true
  }

  private func shouldBypassPopupShortcut(_ action: PopupShortcutAction) -> Bool {
    guard let responder = popupController.currentWindow?.firstResponder as? NSTextView else {
      return false
    }

    if action == .paste || action == .nativePaste {
      return !responder.isFieldEditor
    }

    guard responder.isFieldEditor else {
      return false
    }

    switch action {
    case .focusPrevious, .focusNext, .expandPrevious, .expandNext, .pageUp, .pageDown, .moveSelectionUp, .moveSelectionDown:
      return !responder.isFieldEditor
    default:
      return false
    }
  }

  private func capturePasteTargetApp() {
    guard
      let app = NSWorkspace.shared.frontmostApplication,
      app.bundleIdentifier != Bundle.main.bundleIdentifier
    else {
      return
    }
    pasteTargetApp = app
  }

  private func popupShortcutAction(for event: NSEvent) -> PopupShortcutAction? {
    PopupShortcutAction.allCases.first { action in
      let hotkey = settings.popupHotkeys.hotkey(for: action)
      if hotkey.matches(event) {
        return true
      }

      guard action == .paste || action == .nativePaste else {
        return false
      }

      let alternativeKeyCode: UInt32
      switch hotkey.keyCode {
      case 36:
        alternativeKeyCode = 76
      case 76:
        alternativeKeyCode = 36
      default:
        return false
      }

      return alternativeKeyCode == UInt32(event.keyCode)
        && hotkey.modifiers == AppHotkey.carbonFlags(for: event.modifierFlags)
    }
  }

  private func moveSelectionBlock(by offset: Int) {
    guard let focusedID = uiState.focusedID else {
      return
    }

    let visibleIDs = uiState.visibleItemIDs
    let movingIDs = visibleIDs.filter { uiState.selectedIDs.contains($0) }

    guard !movingIDs.isEmpty else {
      return
    }

    if !workflow.moveSelectionBlock(within: visibleIDs, itemIDs: movingIDs, by: offset) {
      return
    }

    uiState.focusedID = focusedID
    statusMessage = offset < 0 ? "Moved up" : "Moved down"
  }

  private func primaryResourceURL(for item: ClipItem) -> URL? {
    switch item.kind {
    case .image:
      guard let path = item.content.imageAssetPath else {
        return nil
      }
      return imageAssetStore.assetsDirectoryURL.appendingPathComponent(path)
    case .file:
      guard let path = item.content.filePaths?.first else {
        return nil
      }
      return URL(fileURLWithPath: path)
    case .text:
      return nil
    }
  }

  private func saveImageItemAs(_ item: ClipItem) {
    guard let sourceURL = primaryResourceURL(for: item) else {
      statusMessage = "Image missing"
      return
    }

    let panel = NSSavePanel()
    panel.canCreateDirectories = true
    let ext = sourceURL.pathExtension.lowercased()
    let contentType = UTType(filenameExtension: ext) ?? .png
    panel.allowedContentTypes = [contentType]
    panel.nameFieldStringValue = defaultExportName(for: item, fallback: "Image") + ".\(ext.isEmpty ? "png" : ext)"

    guard panel.runModal() == .OK, let destinationURL = panel.url else {
      return
    }

    do {
      try copyResource(from: sourceURL, to: destinationURL)
      statusMessage = "Saved image"
    } catch {
      statusMessage = "Save failed"
    }
  }

  private func saveFileItemAs(_ item: ClipItem) {
    let urls = (item.content.filePaths ?? []).map(URL.init(fileURLWithPath:))
    guard !urls.isEmpty else {
      statusMessage = "File missing"
      return
    }

    if urls.count == 1, let sourceURL = urls.first {
      let panel = NSSavePanel()
      panel.canCreateDirectories = true
      panel.nameFieldStringValue = sourceURL.lastPathComponent

      guard panel.runModal() == .OK, let destinationURL = panel.url else {
        return
      }

      do {
        try copyResource(from: sourceURL, to: destinationURL)
        statusMessage = "Saved file"
      } catch {
        statusMessage = "Save failed"
      }
      return
    }

    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Save"
    panel.message = "Choose a folder to save \(urls.count) files."

    guard panel.runModal() == .OK, let directoryURL = panel.url else {
      return
    }

    do {
      for sourceURL in urls {
        try copyResource(
          from: sourceURL,
          to: directoryURL.appendingPathComponent(sourceURL.lastPathComponent)
        )
      }
      statusMessage = "Saved \(urls.count) files"
    } catch {
      statusMessage = "Save failed"
    }
  }

  private func copyResource(from sourceURL: URL, to destinationURL: URL) throws {
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: destinationURL.path) {
      try fileManager.removeItem(at: destinationURL)
    }
    try fileManager.copyItem(at: sourceURL, to: destinationURL)
  }

  private func defaultExportName(for item: ClipItem, fallback: String) -> String {
    let trimmed = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      return trimmed
    }
    let sanitized = item.titleText.trimmingCharacters(in: .whitespacesAndNewlines)
    return sanitized.isEmpty ? fallback : sanitized
  }

  private func registerHotkey() {
    hotkeyService.register(settings.hotkey) { [weak self] in
      Task { @MainActor [weak self] in
        self?.showPopup()
      }
    }
  }

  private func syncLaunchAtLogin() {
    try? launchAtLoginService.setEnabled(settings.launchAtLogin)
  }
}
