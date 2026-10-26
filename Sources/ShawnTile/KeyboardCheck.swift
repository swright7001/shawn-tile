// Handler and real-window checks use disposable fixture windows and isolated preferences.
import AppKit
import Carbon
import TileCore

func runKeyboardChecks() {
    setbuf(stdout,nil)
    signal(SIGPIPE,SIG_IGN)
    guard AXIsProcessTrusted() else { print("SKIP: keyboard fixture checks require Accessibility for this app."); exit(2) }
    let child = Process(), input = Pipe()
    child.executableURL = URL(fileURLWithPath:CommandLine.arguments[0]); child.arguments = ["--fixture"]; child.standardInput = input
    do { try child.run() } catch { print("FAIL: fixture launch: \(error)"); exit(1) }
    let domain = "com.shawnwright.ShawnTile.KeyboardChecks.\(UUID().uuidString)"
    let prefs = UserDefaults(suiteName:domain)!
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    var manager: WindowManager?, keys: HotKeys?, held: EventHotKeyRef?
    var count = 0, failures = 0
    func check(_ value:Bool,_ name:String) { count += 1; if !value { failures += 1 }; print("\(value ? "PASS" : "FAIL"): \(name)") }
    func finish(_ timeout:Bool = false) {
        if timeout { check(false,"keyboard checks timed out") }
        keys = nil; manager?.enabled = false; manager?.shutdown()
        if let ref = held { UnregisterEventHotKey(ref) }
        try? input.fileHandleForWriting.write(contentsOf:Data("quit\n".utf8))
        if child.isRunning { child.terminate() }
        prefs.removePersistentDomain(forName:domain)
        print("KEYBOARD: \(count) checks, \(failures) failures; fixture PID \(child.processIdentifier) only")
        exit(failures == 0 ? 0 : 1)
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+2) {
        let m = WindowManager(preferences:prefs,onlyPID:child.processIdentifier); manager = m
        check(m.windows.count == 5,"discover only the five disposable windows")
        guard m.windows.count == 5, let screen = m.displays.first else { finish(); return }
        m.update(screen.id) { $0.capacity = 3; $0.autoFit = false; $0.layout = .grid; $0.gap = 10 }; m.enabled = true
        keys = HotKeys(manager:m)
        check(m.shortcutErrors.isEmpty,"all 15 default shortcuts register exclusively")
        let first = m.windows[0].id
        func frame(_ id:String) -> CGRect? { m.windows.first(where:{$0.id == id}).flatMap { axFrame($0.element) } }
        func near(_ a:CGRect?,_ b:CGRect) -> Bool {
            guard let a else { return false }; return abs(a.minX-b.minX)<3 && abs(a.minY-b.minY)<3 && abs(a.width-b.width)<3 && abs(a.height-b.height)<3
        }
        var steps: [(String,()->Void,()->Bool)] = []
        func step(_ name:String,_ perform:@escaping ()->Void,_ verify:@escaping ()->Bool) { steps.append((name,perform,verify)) }
        func event(_ action:ShortcutAction,_ verify:@escaping ()->Bool = {true}) {
            var before = 0
            step("hotkey handler: \(action.title)",{
                before = keys!.dispatchCount; check(keys!.postSmokeEvent(action) == noErr,"post \(action.title) Carbon event")
            },{ keys!.lastAction == action && keys!.dispatchCount == before+1 && verify() })
        }
        func activate(_ id:String) { step("activate fixture \(id)",{ m.activate(id) },{ m.activeID() == id }) }
        for action in [ShortcutAction.capacity1,.capacity2,.capacity3,.capacity4] {
            event(action) { m.configuration(screen.id).capacity == Int(action.eventID) && m.effectiveTiles[screen.id] == Int(action.eventID) }
        }
        activate(first)
        var beforeFocus = CGRect.zero
        step("save Focus baseline",{
            guard let actual = frame(first) else {
                check(false,"fixture window remains discoverable after capacity changes: \(m.windows.map(\.id))")
                finish(); return
            }
            beforeFocus = actual
        },{true})
        event(.focus) { m.focusActive && (frame(first)?.width ?? 0) > screen.area.width*0.8 }
        event(.focus) { !m.focusActive && near(frame(first),beforeFocus) }
        event(.floatWindow)
        let floatingFrame = CGRect(x:screen.area.minX+70,y:screen.area.minY+70,width:280,height:220)
        step("floated window stays where placed",{
            _ = axSetFrame(m.windows.first(where:{$0.id == first})!.element,floatingFrame); m.tidy()
        },{near(frame(first),floatingFrame)})
        activate(first)
        event(.floatWindow) { !near(frame(first),floatingFrame) }
        event(.capacity1)
        activate(first)
        event(.cycleStack) { m.activeID() != first && m.activeID() != nil }
        activate(first)
        event(.nextWindow) { m.activeID() == m.windows[1].id }
        event(.previousWindow) { m.activeID() == first }
        event(.capacity4)
        activate(m.windows[1].id)
        let frames = Geometry.frames(in:screen.area,count:4,settings:m.configuration(screen.id))
        event(.makePrimary) { near(frame(m.windows[1].id),frames[0]) }
        for (action,origin,target) in [(ShortcutAction.swapLeft,1,0),(.swapRight,0,1),(.swapUp,2,1),(.swapDown,1,2)] {
            var selected = ""
            step("select window for \(action.title)",{
                selected = m.windows.first(where:{near(axFrame($0.element),frames[origin])})?.id ?? ""
                m.activate(selected)
            },{!selected.isEmpty && m.activeID() == selected})
            event(action) { near(frame(selected),frames[target]) }
        }
        event(.pause) { !m.enabled }
        event(.pause) { m.enabled }
        var custom = ShortcutAction.pause.defaultBinding; custom.modifiers |= ShortcutBinding.shift
        step("custom binding saves immediately",{ check(keys!.set(.pause,custom) == nil,"save custom pause shortcut") },{keys!.configuration[.pause] == custom})
        step("old combination is released",{
            let old = ShortcutAction.pause.defaultBinding
            let result = RegisterEventHotKey(old.keyCode!,old.modifiers,EventHotKeyID(signature:0x54455354,id:100),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&held)
            check(result == noErr,"old pause key can be registered again")
            if let ref = held { UnregisterEventHotKey(ref); held = nil }
        },{true})
        var saved = ShortcutConfiguration()
        step("conflicting OS registration rolls back",{
            saved = keys!.configuration
            let blocked = ShortcutBinding(keyCode:UInt32(kVK_F12),modifiers:ShortcutBinding.control | ShortcutBinding.option | ShortcutBinding.command | ShortcutBinding.shift)
            let result = RegisterEventHotKey(blocked.keyCode!,blocked.modifiers,EventHotKeyID(signature:0x54455354,id:101),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&held)
            check(result == noErr,"reserve a controlled conflicting shortcut")
            check(keys!.set(.pause,blocked) != nil,"reject unavailable shortcut")
            if let ref = held { UnregisterEventHotKey(ref); held = nil }
        },{keys!.configuration == saved && m.shortcutErrors.isEmpty})
        event(.pause) { !m.enabled }
        event(.pause) { m.enabled }
        step("duplicate combination leaves configuration intact",{
            check(keys!.set(.pause,keys!.configuration[.focus]) != nil,"reject duplicate action binding")
        },{keys!.configuration == saved})
        step("disabled action releases registration",{
            check(keys!.set(.pause,.disabled) == nil,"disable pause shortcut")
        },{keys!.configuration[.pause] == .disabled})
        var disabledCount = 0
        step("disabled action ignores stale hotkey events",{
            disabledCount = keys!.dispatchCount; _ = keys!.postSmokeEvent(.pause)
        },{keys!.dispatchCount == disabledCount && m.enabled})
        step("custom preferences reload after re-registration",{
            check(keys!.set(.pause,custom) == nil,"restore custom pause shortcut")
            keys = nil; keys = HotKeys(manager:m)
        },{keys!.configuration[.pause] == custom && m.shortcutErrors.isEmpty})
        event(.pause) { !m.enabled }
        event(.pause) { m.enabled }
        step("restore default shortcuts",{
            check(keys!.save(ShortcutConfiguration()) == nil,"save default shortcuts")
        },{keys!.configuration == ShortcutConfiguration() && m.shortcutErrors.isEmpty})
        step("resolve multiple startup conflicts one at a time",{
            keys = nil
            var second: EventHotKeyRef?
            let pause = ShortcutAction.pause.defaultBinding, focus = ShortcutAction.focus.defaultBinding
            let firstStatus = RegisterEventHotKey(pause.keyCode!,pause.modifiers,EventHotKeyID(signature:0x54455354,id:200),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&held)
            let secondStatus = RegisterEventHotKey(focus.keyCode!,focus.modifiers,EventHotKeyID(signature:0x54455354,id:201),GetApplicationEventTarget(),OptionBits(kEventHotKeyExclusive),&second)
            check(firstStatus == noErr && secondStatus == noErr,"reserve two startup conflicts")
            keys = HotKeys(manager:m)
            check(m.shortcutErrors.count == 2,"report both unavailable defaults")
            check(keys!.set(.pause,custom) == nil && m.shortcutErrors.count == 1,"fix one conflict while another remains")
            check(keys!.set(.focus,.disabled) == nil && m.shortcutErrors.isEmpty,"disable remaining unavailable binding")
            if let ref = held { UnregisterEventHotKey(ref); held = nil }
            if let ref = second { UnregisterEventHotKey(ref) }
            check(keys!.save(ShortcutConfiguration()) == nil,"restore defaults after conflict recovery")
        },{keys!.configuration == ShortcutConfiguration() && m.shortcutErrors.isEmpty})
        step("register Screen Sharing preset",{
            check(keys!.save(.screenSharing) == nil,"save Screen Sharing shortcuts")
        },{keys!.configuration == .screenSharing && m.shortcutErrors.isEmpty})
        event(.pause) { !m.enabled }
        event(.pause) { m.enabled }
        var index = 0
        func next() {
            guard index < steps.count else { finish(); return }
            let current = steps[index]; index += 1; current.1()
            DispatchQueue.main.asyncAfter(deadline:.now()+0.55) { check(current.2(),current.0); next() }
        }
        // Allow the fixture's initial layout to settle before changing capacity.
        DispatchQueue.main.asyncAfter(deadline:.now()+0.8) { next() }
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+60) { finish(true) }
    app.run()
}
