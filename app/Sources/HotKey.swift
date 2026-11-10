import Carbon.HIToolbox

/// Global keyboard shortcuts with Control+Option+Command. Carbon hot keys need
/// no Accessibility or Input Monitoring permission: macOS only tells the app
/// when its own key combinations are pressed.
@MainActor
enum HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var refs: [UInt32: EventHotKeyRef] = [:]
    private static var handlerInstalled = false
    private static let signature = OSType(0x554E_5354)  // 'UNST'

    /// Registers Control+Option+Command plus the key. Returns noErr on
    /// success; eventHotKeyExistsErr means another app holds the combination.
    static func register(id: UInt32, keyCode: Int, _ action: @escaping () -> Void) -> OSStatus {
        handlers[id] = action
        installHandler()
        if refs[id] != nil { return noErr }
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(controlKey | optionKey | cmdKey),
            EventHotKeyID(signature: signature, id: id), GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs[id] = ref }
        return status
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // A C callback can't capture context, so it finds the action through
        // the static dictionary, by the ID of the key that was pressed.
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            MainActor.assumeIsolated { HotKey.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }
}
