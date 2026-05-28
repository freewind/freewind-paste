import Carbon
import Foundation

final class HotkeyService {
  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?
  private var action: (() -> Void)?

  func register(_ hotkey: AppHotkey, action: @escaping () -> Void) {
    unregister()
    self.action = action

    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData in
        guard let event else {
          return noErr
        }

        var hotKeyID = EventHotKeyID()
        GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &hotKeyID
        )

        guard hotKeyID.id == 1, let userData else {
          return noErr
        }

        let service = Unmanaged<HotkeyService>.fromOpaque(userData).takeUnretainedValue()
        service.action?()
        return noErr
      },
      1,
      &eventSpec,
      Unmanaged.passUnretained(self).toOpaque(),
      &handlerRef
    )

    let hotKeyID = EventHotKeyID(signature: OSType(0x50424152), id: 1)
    RegisterEventHotKey(
      UInt32(hotkey.keyCode),
      hotkey.modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
  }

  func unregister() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    if let handlerRef {
      RemoveEventHandler(handlerRef)
      self.handlerRef = nil
    }
  }
}
