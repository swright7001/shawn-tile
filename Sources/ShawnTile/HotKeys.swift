import Carbon
import AppKit
import Combine
import TileCore

final class HotKeys: ObservableObject {
    @Published private(set) var configuration = ShortcutConfiguration()
    private var refs: [UInt32:EventHotKeyRef] = [:]
    private var registrationFailures: [UInt32:String] = [:]
    private var handler: EventHandlerRef?
    private weak var manager: WindowManager?
    private let preferences: UserDefaults
    @Published private(set) var lastAction: ShortcutAction?
    private(set) var dispatchCount = 0
    init(manager:WindowManager) {
        self.manager = manager; preferences = manager.preferences
        if let data = preferences.data(forKey:"shortcuts.v1") {
            if let saved = try? JSONDecoder().decode(ShortcutConfiguration.self,from:data), saved.validationError == nil { configuration = saved }
            else { manager.shortcutErrors = ["Saved shortcuts could not be loaded. Defaults are active."] }
        }
        var type = EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _,event,context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&id)
            guard status == noErr else { return status }
            let owner = Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue()
            guard id.signature == 0x5354494C, owner.refs[id.id] != nil,
                  let action = ShortcutAction.allCases.first(where:{$0.eventID == id.id}) else { return OSStatus(eventNotHandledErr) }
            owner.perform(action)
            return noErr
        },1,&type,Unmanaged.passUnretained(self).toOpaque(),&handler)
        if status != noErr { manager.shortcutErrors.append("Could not start keyboard shortcuts (\(status))."); return }
        manager.shortcutErrors += register(configuration)
    }
    /// Changes take effect immediately. Failed registration restores the previous bindings.
    @discardableResult func save(_ proposed:ShortcutConfiguration) -> String? {
        if let error = proposed.validationError { return error }
        guard handler != nil else { return "Keyboard shortcuts could not start. Restart Shawn Tile and try again." }
        let previouslyWorking = Set(refs.keys)
        unregister()
        let failures = register(proposed)
        // An unchanged shortcut that was already unavailable must not prevent
        // fixing other conflicts one at a time. Never lose a working binding.
        let newlyFailed = ShortcutAction.allCases.contains { action in
            registrationFailures[action.eventID] != nil &&
                (previouslyWorking.contains(action.eventID) || proposed[action] != configuration[action])
        }
        if newlyFailed {
            unregister(); manager?.shortcutErrors = register(configuration)
            return failures.joined(separator:"\n")
        }
        configuration = proposed
        preferences.set(try! JSONEncoder().encode(proposed),forKey:"shortcuts.v1")
        manager?.shortcutErrors = failures
        return nil
    }
    @discardableResult func set(_ action:ShortcutAction,_ binding:ShortcutBinding) -> String? {
        var proposed = configuration; proposed[action] = binding; return save(proposed)
    }
    private func register(_ config:ShortcutConfiguration) -> [String] {
        var errors: [String] = []
        registrationFailures = [:]
        for action in ShortcutAction.allCases {
            let binding = config[action]
            guard let key = binding.keyCode else { continue }
            var reference:EventHotKeyRef?
            let status = RegisterEventHotKey(key,binding.modifiers,EventHotKeyID(signature:0x5354494C,id:action.eventID),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&reference)
            if status == noErr, let reference { refs[action.eventID] = reference }
            else {
                let message = "\(action.title): \(binding.label) is unavailable (macOS \(status)). Choose another combination."
                errors.append(message); registrationFailures[action.eventID] = message
            }
        }
        return errors
    }
    private func unregister() { for ref in refs.values { UnregisterEventHotKey(ref) }; refs = [:] }
    private func perform(_ action:ShortcutAction) {
        guard let manager else { return }
        lastAction = action; dispatchCount += 1
        switch action {
        case .capacity1,.capacity2,.capacity3,.capacity4:
            guard let id = manager.activeDisplay() else { return }
            manager.update(id) { $0.capacity = Int(action.eventID) }
        case .focus: manager.toggleFocus()
        case .floatWindow: manager.toggleFloat()
        case .cycleStack: manager.cycleStack()
        case .nextWindow: manager.cycleWindow(1)
        case .previousWindow: manager.cycleWindow(-1)
        case .makePrimary: manager.makePrimary()
        case .pause: manager.enabled.toggle()
        case .swapLeft: manager.swap(direction:CGPoint(x:-1,y:0))
        case .swapRight: manager.swap(direction:CGPoint(x:1,y:0))
        case .swapUp: manager.swap(direction:CGPoint(x:0,y:-1))
        case .swapDown: manager.swap(direction:CGPoint(x:0,y:1))
        }
    }
    /// Posts a discrete Carbon hotkey event for handler checks, not a simulated keystroke.
    func postSmokeEvent(_ action:ShortcutAction = .capacity1) -> OSStatus {
        var event: EventRef?
        let created = CreateEvent(nil,OSType(kEventClassKeyboard),UInt32(kEventHotKeyPressed),GetCurrentEventTime(),EventAttributes(kEventAttributeUserEvent),&event)
        guard created == noErr, let event else { return created }
        defer { ReleaseEvent(event) }
        var id = EventHotKeyID(signature:0x5354494C,id:action.eventID)
        let parameter = SetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),MemoryLayout<EventHotKeyID>.size,&id)
        guard parameter == noErr else { return parameter }
        return PostEventToQueue(GetMainEventQueue(),event,EventPriority(kEventPriorityStandard))
    }
    deinit { unregister(); if let handler { RemoveEventHandler(handler) } }
}
