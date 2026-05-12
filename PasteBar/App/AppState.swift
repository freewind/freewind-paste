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
  @Published var settings: AppSettings
  @Published var statusMessage: String
  @Published var isPopupVisible: Bool
  @Published var searchFocusNonce: Int
  @Published var imageOutputMode: ImageOutputMode
  @Published var imageLowResMaxDimension: Double
  @Published var accessibilityGranted: Bool

  let persistence: ClipPersistence
  let imageAssetStore: ImageAssetStore
  let captureService: ClipboardCaptureService
  let pasteService: ClipboardPasteService
  let hotkeyService: HotkeyService
  let launchAtLoginService: LaunchAtLoginService
  let popupController: PopupWindowController
  let settingsWindowController: SettingsWindowController
  let menuBarController: MenuBarController
  private var isBootstrapped = false

  init(
    persistence: ClipPersistence = AppPaths.persistence,
    hotkeyService: HotkeyService = HotkeyService(),
    launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService(),
    popupController: PopupWindowController = PopupWindowController(),
    settingsWindowController: SettingsWindowController = SettingsWindowController(),
    menuBarController: MenuBarController = MenuBarController()
  ) {
    self.persistence = persistence
    imageAssetStore = ImageAssetStore(assetsDirectoryURL: AppPaths.assetsDirectoryURL)
    let parser = ClipboardParseService(imageAssetStore: imageAssetStore)
    captureService = ClipboardCaptureService(parser: parser)
    pasteService = ClipboardPasteService(trigger: AccessibilityPasteTrigger())
    self.hotkeyService = hotkeyService
    self.launchAtLoginService = launchAtLoginService
    self.popupController = popupController
    self.settingsWindowController = settingsWindowController
    self.menuBarController = menuBarController
    let loadedSettings = persistence.loadSettings()
    settings = loadedSettings
    store = ClipStore(
      items: persistence.loadItems(),
      previewLocked: loadedSettings.previewLocked
    )
    statusMessage = "Ready"
    isPopupVisible = false
    searchFocusNonce = 0
    imageOutputMode = .original
    imageLowResMaxDimension = 512
    accessibilityGranted = AXIsProcessTrusted()
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

    hotkeyService.register(settings.hotkey) { [weak self] in
      Task { @MainActor [weak self] in
        self?.showPopup()
      }
    }

    if launchAtLoginService.isEnabled() != settings.launchAtLogin {
      try? launchAtLoginService.setEnabled(settings.launchAtLogin)
    }

    captureService.start { [weak self] item in
      Task { @MainActor [weak self] in
        self?.store.insertOrPromote(item)
        self?.statusMessage = "Captured \(item.kind.rawValue)"
        self?.persistItems()
      }
    }

    showPopup()
  }

  func showPopup() {
    store.selectFirstVisible()
    searchFocusNonce += 1
    popupController.show(with: self)
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

    let field = NSTextField(string: store.items.first(where: { $0.id == id })?.label ?? "")
    field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
    alert.accessoryView = field

    if alert.runModal() == .alertFirstButtonReturn {
      store.updateLabel(for: id, label: field.stringValue)
      persistItems()
    }
  }

  func pasteSelection(mode: PasteMode) {
    let items = store.selectedItems.isEmpty
      ? [store.focusedItem].compactMap { $0 }
      : store.selectedItems
    pasteService.paste(
      items: items,
      mode: mode,
      imageOutputMode: imageOutputMode,
      imageMaxDimension: imageLowResMaxDimension
    )
    let usesLowResolution = imageOutputMode == .lowResolution && items.contains { $0.kind == .image }
    switch (mode, usesLowResolution) {
    case (.normalEnter, true):
      statusMessage = "Pasted low-res image"
    case (.nativeShiftEnter, true):
      statusMessage = "Native pasted low-res image"
    case (.normalEnter, false):
      statusMessage = "Pasted"
    case (.nativeShiftEnter, false):
      statusMessage = "Native pasted"
    }
  }

  func updateSettings(_ mutate: (inout AppSettings) -> Void) {
    mutate(&settings)
    store.previewLocked = settings.previewLocked
    try? persistence.saveSettings(settings)

    hotkeyService.register(settings.hotkey) { [weak self] in
      Task { @MainActor [weak self] in
        self?.showPopup()
      }
    }

    try? launchAtLoginService.setEnabled(settings.launchAtLogin)
  }

  func persistItems() {
    try? persistence.saveItems(store.items)
    let keptImages = Set(
      store.items.compactMap { item in
        item.kind == .image ? item.content.imageAssetPath : nil
      }
    )
    imageAssetStore.prune(keeping: keptImages)
  }

  func clearAll() {
    store.clearAll()
    try? persistence.saveItems([])
    imageAssetStore.prune(keeping: Set<String>())
    statusMessage = "Cleared"
  }

  func copyLowResolutionImage(from item: ClipItem) {
    guard
      item.kind == .image,
      let path = item.content.imageAssetPath,
      let image = imageAssetStore.load(
        relativePath: path,
        mode: .lowResolution,
        maxDimension: imageLowResMaxDimension
      ),
      let saved = try? imageAssetStore.save(image)
    else {
      return
    }

    let trimmedLabel = item.label.trimmingCharacters(in: .whitespacesAndNewlines)
    let newItem = ClipItem(
      kind: .image,
      favorite: item.favorite,
      label: trimmedLabel.isEmpty ? "" : "\(trimmedLabel) low",
      content: .image(assetPath: saved.relativePath),
      meta: ClipMeta(
        imageWidth: saved.width,
        imageHeight: saved.height,
        imageHash: saved.hash,
        imageByteSize: saved.byteSize
      )
    )
    store.insertOrPromote(newItem)
    persistItems()
    statusMessage = "Copied low-res image"
  }

  func requestAccessibilityPermission() {
    _ = pasteService.trigger.requestPermissionIfNeeded()
    refreshAccessibilityStatus()
  }

  func openAccessibilitySettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
      return
    }
    NSWorkspace.shared.open(url)
  }

  func refreshAccessibilityStatus() {
    accessibilityGranted = AXIsProcessTrusted()
  }
}
