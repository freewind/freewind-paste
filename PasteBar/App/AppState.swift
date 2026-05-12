import AppKit
import Combine
import Foundation

@MainActor
enum AppPaths {
  static let persistence = ClipPersistence()
  static let assetsDirectoryURL = persistence.assetsURL.appendingPathComponent("images", isDirectory: true)
}

@MainActor
final class AppState: ObservableObject {
  let store: ClipStore
  let uiState: ClipViewState
  @Published var settings: AppSettings
  @Published var statusMessage: String
  @Published var isPopupVisible: Bool
  @Published var searchFocusNonce: Int
  @Published var imageOutputMode: ImageOutputMode
  @Published var imageLowResMaxDimension: Double
  @Published var accessibilityGranted: Bool

  let repository: ClipRepository
  let imageAssetStore: ImageAssetStore
  let captureService: ClipboardCaptureService
  let pasteService: ClipboardPasteService
  let workflowService: ClipWorkflowService
  let accessibilityAccess: AccessibilityPasteTrigger
  let hotkeyService: HotkeyService
  let launchAtLoginService: LaunchAtLoginService
  let popupController: PopupWindowController
  let transientImagePreviewController: TransientImagePreviewController
  let settingsWindowController: SettingsWindowController
  let menuBarController: MenuBarController
  private var isBootstrapped = false

  init(
    persistence: ClipPersistence = AppPaths.persistence,
    accessibilityAccess: AccessibilityPasteTrigger = AccessibilityPasteTrigger(),
    hotkeyService: HotkeyService = HotkeyService(),
    launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService(),
    popupController: PopupWindowController = PopupWindowController(),
    transientImagePreviewController: TransientImagePreviewController = TransientImagePreviewController(),
    settingsWindowController: SettingsWindowController = SettingsWindowController(),
    menuBarController: MenuBarController = MenuBarController()
  ) {
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
    workflowService = ClipWorkflowService(
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
    if store.pruneExpiredTrash() {
      workflowService.commitItems()
    }
    workflowService.bootstrap()
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
        self?.workflowService.capture(item)
        self?.statusMessage = "Captured \(item.kind.rawValue)"
      }
    }

    showPopup()
  }

  func showPopup() {
    uiState.selectFirstVisible()
    searchFocusNonce += 1
    popupController.show(with: self)
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

    let field = NSTextField(string: workflowService.labelValue(for: id))
    field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
    alert.accessoryView = field

    if alert.runModal() == .alertFirstButtonReturn {
      workflowService.updateLabel(for: id, label: field.stringValue)
    }
  }

  func pasteSelection(mode: PasteMode) {
    if let message = workflowService.pasteSelection(
      mode: mode,
      imageOutputMode: imageOutputMode,
      imageMaxDimension: imageLowResMaxDimension
    ) {
      statusMessage = message
      if message.hasPrefix("Pasted") || message.hasPrefix("Native pasted") {
        hidePopup()
      }
    }
  }

  func deleteSelection(permanently: Bool) {
    workflowService.delete(uiState.selectedIDs, permanently: permanently)
    statusMessage = permanently ? "Deleted permanently" : "Moved to trash"
  }

  func deleteCheckedVisible(permanently: Bool) {
    workflowService.delete(Set(uiState.checkedVisibleItems.map(\.id)), permanently: permanently)
    statusMessage = permanently ? "Deleted permanently" : "Moved to trash"
  }

  func restoreSelection() {
    workflowService.restore(uiState.selectedIDs)
    statusMessage = "Restored"
  }

  func restore(_ id: String) {
    workflowService.restore([id])
    statusMessage = "Restored"
  }

  func updateSettings(_ mutate: (inout AppSettings) -> Void) {
    mutate(&settings)
    repository.saveSettings(settings)
    registerHotkey()
    syncLaunchAtLogin()
  }

  func clearAll() {
    workflowService.clearAll()
    statusMessage = "Cleared"
  }

  func copyLowResolutionImage(from item: ClipItem) {
    if workflowService.copyLowResolutionImage(from: item, imageMaxDimension: imageLowResMaxDimension) {
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
    workflowService.moveItems(within: sectionIDs, from: offsets, to: destination)
  }

  func reverseSelection() {
    workflowService.reverseSelection()
  }

  func toggleFavorite(for id: String) {
    workflowService.toggleFavorite(for: id)
  }

  func setFavorite(_ ids: Set<String>, favorite: Bool) {
    workflowService.setFavorite(ids, favorite: favorite)
  }

  func updateText(for id: String, text: String) {
    workflowService.updateText(
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
      event.type == .keyDown,
      event.keyCode == 51
    else {
      return event
    }

    if shouldBypassDeleteShortcut() {
      return event
    }

    deleteSelection(permanently: event.modifierFlags.contains(.command) || uiState.currentTab == .trash)
    return nil
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
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = defaultExportName(for: item, fallback: "Image") + ".png"

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
