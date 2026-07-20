import AppKit
import Carbon.HIToolbox

/// Global hotkey via Carbon `RegisterEventHotKey` (PRD §8.5).
/// Chosen deliberately over CGEventTap: needs NO accessibility permission and
/// works under App Sandbox / App Store — the core reason it's here.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var refs: [UInt32: EventHotKeyRef?] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    private init() { installDispatcher() }

    /// Register a hotkey. `keyCode` is a Carbon virtual key; `modifiers` a Carbon mask.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32 {
        let id = nextID; nextID += 1
        handlers[id] = handler

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("TOKY"), id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            refs[id] = hotKeyRef
        } else {
            NSLog("Hotkey register failed (\(status)) for id \(id)")
            handlers[id] = nil
        }
        return id
    }

    func unregister(_ id: UInt32) {
        if let ref = refs[id], let ref { UnregisterEventHotKey(ref) }
        refs[id] = nil
        handlers[id] = nil
    }

    private func installDispatcher() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handlers[hkID.id]?()
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }
}

/// Carbon virtual key codes used by TaskOcean's default shortcuts.
enum KeyCodes {
    static let space: UInt32 = 49
    static let t: UInt32 = 17
}

/// Carbon modifier masks.
enum HotKeyModifiers {
    static let option = UInt32(optionKey)
    static let command = UInt32(cmdKey)
    static let control = UInt32(controlKey)
    static let shift = UInt32(shiftKey)
}

private func fourCharCode(_ string: String) -> FourCharCode {
    var code: FourCharCode = 0
    for scalar in string.unicodeScalars.prefix(4) {
        code = (code << 8) + FourCharCode(scalar.value & 0xFF)
    }
    return code
}
