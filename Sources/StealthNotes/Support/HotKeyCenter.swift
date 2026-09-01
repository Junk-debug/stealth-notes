import AppKit
import Carbon.HIToolbox

/// Registers Carbon global hotkeys: toggle all overlays (configurable) and section paging (⌃⌥←/→).
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var refs: [EventHotKeyRef?] = []
    private var handlerInstalled = false

    func register(optionIndex: Int) {
        let option = hotKeyOptions.indices.contains(optionIndex) ? hotKeyOptions[optionIndex] : hotKeyOptions[0]
        for ref in refs { if let ref { UnregisterEventHotKey(ref) } }
        refs.removeAll()

        if !handlerInstalled {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                DispatchQueue.main.async {
                    switch hkID.id {
                    case 1: OverlayManager.shared.toggleAllVisibility()
                    case 2: OverlayManager.shared.page(1)
                    case 3: OverlayManager.shared.page(-1)
                    default: break
                    }
                }
                return noErr
            }, 1, &eventType, nil, nil)
            handlerInstalled = true
        }

        let signature = OSType(0x534E_5453) // "SNTS"
        var toggleRef: EventHotKeyRef?
        RegisterEventHotKey(option.keyCode, option.modifiers, EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), 0, &toggleRef)
        var nextRef: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_RightArrow), UInt32(controlKey | optionKey), EventHotKeyID(signature: signature, id: 2), GetApplicationEventTarget(), 0, &nextRef)
        var prevRef: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_LeftArrow), UInt32(controlKey | optionKey), EventHotKeyID(signature: signature, id: 3), GetApplicationEventTarget(), 0, &prevRef)
        refs = [toggleRef, nextRef, prevRef]
    }
}
