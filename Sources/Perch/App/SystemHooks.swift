import AppKit
import Carbon.HIToolbox
import ServiceManagement

/// A shortcut that works whichever app is in front. Carbon's hot keys need no permission,
/// unlike watching every key press.
@MainActor
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private nonisolated(unsafe) static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1

    /// `keyCode` is a `kVK_…` code, `modifiers` Carbon's `cmdKey`, `controlKey` and so on.
    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        let id = Self.nextID
        Self.nextID += 1
        Self.actions[id] = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKey = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            let id = hotKey.id
            DispatchQueue.main.async { HotKey.actions[id]?() }
            return noErr
        }, 1, &spec, nil, &handler)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), EventHotKeyID(signature: OSType(0x5052_4348), id: id),
                            GetApplicationEventTarget(), 0, &ref)   // 'PRCH'
    }
}

/// "Open at login", through macOS's own login items list (System Settings › General › Login Items).
@MainActor
enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Perch: login item change failed: \(error)")
        }
    }
}
