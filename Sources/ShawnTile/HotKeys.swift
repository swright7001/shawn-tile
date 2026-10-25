import Carbon
import AppKit
final class HotKeys {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var actions: [UInt32:()->Void] = [:]
    init(manager:WindowManager) {
        var type = EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _,event,context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&id)
            guard status == noErr else { return status }
            Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue().actions[id.id]?()
            return noErr
        },1,&type,Unmanaged.passUnretained(self).toOpaque(),&handler)
        let mods = UInt32(controlKey | optionKey)
        for (i,key) in [kVK_ANSI_1,kVK_ANSI_2,kVK_ANSI_3,kVK_ANSI_4].enumerated() {
            bind(key,mods|UInt32(cmdKey),"Capacity \(i+1)",manager) { [weak manager] in
                guard let manager, let id = manager.activeDisplay() else { return }; manager.update(id) { $0.capacity = i+1 }
            }
        }
        bind(kVK_ANSI_Z,mods,"Focus",manager) { [weak manager] in manager?.toggleFocus() }
        bind(kVK_ANSI_F,mods,"Float",manager) { [weak manager] in manager?.toggleFloat() }
        bind(kVK_ANSI_Grave,mods,"Cycle stack",manager) { [weak manager] in manager?.cycleStack() }
        bind(kVK_ANSI_RightBracket,mods,"Next window",manager) { [weak manager] in manager?.cycleWindow(1) }
        bind(kVK_ANSI_LeftBracket,mods,"Previous window",manager) { [weak manager] in manager?.cycleWindow(-1) }
        bind(kVK_Return,mods,"Make primary",manager) { [weak manager] in manager?.makePrimary() }
        bind(kVK_ANSI_P,mods,"Pause",manager) { [weak manager] in guard let manager else { return }; manager.enabled.toggle() }
        for (key,direction) in [(kVK_LeftArrow,CGPoint(x:-1,y:0)),(kVK_RightArrow,CGPoint(x:1,y:0)),(kVK_UpArrow,CGPoint(x:0,y:-1)),(kVK_DownArrow,CGPoint(x:0,y:1))] {
            bind(key,mods,"Swap \(key)",manager) { [weak manager] in manager?.swap(direction:direction) }
        }
    }
    /// Smoke check: posts a discrete Carbon hotkey event, not a simulated keystroke.
    func postSmokeEvent() -> OSStatus {
        var event: EventRef?
        let created = CreateEvent(nil,OSType(kEventClassKeyboard),UInt32(kEventHotKeyPressed),GetCurrentEventTime(),EventAttributes(kEventAttributeUserEvent),&event)
        guard created == noErr, let event else { return created }
        var id = EventHotKeyID(signature:0x5354494C,id:1)
        let parameter = SetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),MemoryLayout<EventHotKeyID>.size,&id)
        guard parameter == noErr else { return parameter }
        return PostEventToQueue(GetMainEventQueue(),event,EventPriority(kEventPriorityStandard))
    }
    private func bind(_ key:Int,_ modifiers:UInt32,_ label:String,_ manager:WindowManager,_ action:@escaping ()->Void) {
        let id = UInt32(actions.count+1)
        var reference:EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(key),modifiers,EventHotKeyID(signature:0x5354494C,id:id),GetApplicationEventTarget(),0,&reference)
        // Reserve failed IDs too so the next binding cannot alias them.
        actions[id] = action
        if status == noErr, let reference { refs.append(reference) }
        else { manager.shortcutErrors.append("\(label) unavailable (\(status))") }
    }
    deinit { for ref in refs { UnregisterEventHotKey(ref) }; if let handler { RemoveEventHandler(handler) } }
}
