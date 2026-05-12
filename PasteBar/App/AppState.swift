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

  let persistence: ClipPersistence
  let imageAssetStore: ImageAssetStore
  let captureService: ClipboardCaptureService
  let pasteService: ClipboardPasteService
  let hotkeyService: HotkeyService
  let launchAtLoginService: LaunchAtLoginService
  let popupController: PopupWindowController
  private var isBootstrapped = false

  init(
    persistence: ClipPersistence = AppPaths.persistence,
    hotkeyService: HotkeyService = HotkeyService(),
    launchAtLoginService: LaunchAtLoginService = LaunchAtLoginService(),
    popupController: PopupWindowController = PopupWindowController()
  ) {
    self.persistence = persistence
    imageAssetStore = ImageAssetStore(assetsDirectoryURL: AppPaths.assetsDirectoryURL)
    let parser = ClipboardParseService(imageAssetStore: imageAssetStore)
    captureService = ClipboardCaptureService(parser: parser)
    pasteService = ClipboardPasteService(trigger: AccessibilityPasteTrigger())
    self.hotkeyService = hotkeyService
    self.launchAtLoginService = launchAtLoginService
    self.popupController = popupController
    let loadedSettings = persistence.loadSettings()
    settings = loadedSettings
    store = ClipStore(
      items: persistence.loadItems(),
      previewLocked: loadedSettings.previewLocked
    )
    statusMessage = "Ready"
    isPopupVisible = false

    Task { @MainActor [weak self] in
      self?.bootstrap()
    }
  }

  func bootstrap() {
    guard !isBootstrapped else {
      return
    }
    isBootstrapped = true

    hotkeyService.register(settings.hotkey) { [weak self] in
      Task { @MainActor [weak self] in
        self?.togglePopup()
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
  }

  func togglePopup() {
    popupController.toggle(with: self)
  }

  func pasteSelection(mode: PasteMode) {
    let items = store.selectedItems.isEmpty
      ? [store.focusedItem].compactMap { $0 }
      : store.selectedItems
    pasteService.paste(items: items, mode: mode)
    statusMessage = mode == .normalEnter ? "Pasted" : "Native pasted"
  }

  func updateSettings(_ mutate: (inout AppSettings) -> Void) {
    mutate(&settings)
    store.previewLocked = settings.previewLocked
    try? persistence.saveSettings(settings)

    hotkeyService.register(settings.hotkey) { [weak self] in
      Task { @MainActor [weak self] in
        self?.togglePopup()
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
}
