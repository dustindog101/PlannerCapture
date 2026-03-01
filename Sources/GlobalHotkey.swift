import Foundation
import Carbon
import AppKit

class GlobalHotkey {
    static let shared = GlobalHotkey()
    var action: (() -> Void)?
    
    func register(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        self.action = action
        
        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        
        let signature: OSType = 1347171152 // 'PLCP'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, event, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let mySelf = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
            mySelf.action?()
            return noErr
        }, 1, &eventType, ptr, nil)
        
        var hotKeyRef: EventHotKeyRef?
        RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
