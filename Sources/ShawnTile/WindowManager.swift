import AppKit
import ApplicationServices
import Combine
import TileCore

final class WindowManager: ObservableObject {
    @Published var enabled: Bool { didSet {
        preferences.set(enabled,forKey:"enabled")
        if !enabled { restoreFocus() }; refresh(force:true)
    } }
    @Published var trusted = AXIsProcessTrusted()
    @Published var displays = connectedDisplays()
    @Published var settings: [String:DisplaySettings] = [:]
    @Published var excluded: Set<String> = []
    @Published var status = "Paused — enable when you are ready"
    @Published var windowCount = 0
    @Published var focusActive = false
    @Published var shortcutErrors: [String] = []
    @Published var effectiveTiles: [String:Int] = [:]
    @Published var effectiveLayouts: [String:Layout] = [:]
    @Published var fittingDetails: [String:String] = [:]
    private var minimums: [String:CGSize] = [:]
    private var fittedFrames: [String:[CGRect]] = [:]
    private var layoutGeneration = 0
    private var fitCheck: DispatchWorkItem?
    private var fitPending = false
    private var settledSizes: [String:CGSize] = [:]
    @Published var runningApps: [NSRunningApplication] = []
    private(set) var windows: [ManagedWindow] = []
    private var states: [String:TileState] = [:]
    let preferences: UserDefaults
    private let onlyPID: pid_t?
    private var nextID = 0
    private var originals: [String:(AXUIElement,CGRect)] = [:]
    private var focusSnapshot: [String:(AXUIElement,CGRect)] = [:]
    private var focusedID: String?
    private var lastActiveID: String?
    private var floating: [String:AXUIElement] = [:]
    private var observers: [pid_t:AXObserver] = [:]
    private var tokens: [NSObjectProtocol] = []
    private var timer: Timer?
    private var pending: DispatchWorkItem?
    private var applying = false
    private var lastSignature = ""
    private var discoveryNotBefore: TimeInterval = 0
    var menuChanged: (() -> Void)?

    init(preferences: UserDefaults = .standard, onlyPID: pid_t? = nil) {
        self.preferences = preferences; self.onlyPID = onlyPID
        enabled = preferences.bool(forKey:"enabled")
        if let data = preferences.data(forKey:"displays"), let s = try? JSONDecoder().decode([String:DisplaySettings].self,from:data) { settings = s }
        excluded = Set(preferences.stringArray(forKey:"excluded") ?? ["com.apple.systempreferences","com.apple.calculator","com.apple.Stickies"])
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,NSWorkspace.didTerminateApplicationNotification,NSWorkspace.didActivateApplicationNotification,NSWorkspace.didHideApplicationNotification,NSWorkspace.didUnhideApplicationNotification,NSWorkspace.activeSpaceDidChangeNotification,NSWorkspace.didWakeNotification] {
            tokens.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.schedule() })
        }
        tokens.append(NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in self?.schedule() })
        timer = Timer.scheduledTimer(withTimeInterval:1.5,repeats:true) { [weak self] _ in self?.refresh() }
        refresh()
    }
    func configuration(_ id:String) -> DisplaySettings { settings[id] ?? DisplaySettings() }
    func update(_ id:String, _ change:(inout DisplaySettings)->Void) {
        var value = configuration(id); change(&value); value.capacity = min(4,max(1,value.capacity)); value.gap = min(32,max(0,value.gap))
        settings[id] = value
        if let data = try? JSONEncoder().encode(settings) { preferences.set(data,forKey:"displays") }
        // Re-measure when the arrangement changes. An app's accepted size can
        // depend on its previous frame, so do not carry stale constraints over.
        minimums = [:]
        restoreFocus(); lastSignature = ""; refresh(force:true)
    }
    func exclude(_ bundle:String) {
        restoreFocus()
        if excluded.contains(bundle) { excluded.remove(bundle) } else { excluded.insert(bundle) }
        preferences.set(excluded.sorted(),forKey:"excluded"); refresh(force:true)
    }
    func requestPermission() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary)
        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func schedule() {
        guard !applying else { return }
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pending = work; DispatchQueue.main.asyncAfter(deadline:.now()+0.22,execute:work)
    }
    private func attachObservers() {
        let apps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != getpid() && (onlyPID == nil || $0.processIdentifier == onlyPID) }
        let pids = Set(apps.map(\.processIdentifier))
        for pid in Array(observers.keys) where !pids.contains(pid) {
            if let o = observers.removeValue(forKey:pid) { CFRunLoopRemoveSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(o),.commonModes) }
        }
        for app in apps where observers[app.processIdentifier] == nil {
            var observer: AXObserver?
            let callback: AXObserverCallback = { _,_,_,context in
                guard let context else { return }
                let manager = Unmanaged<WindowManager>.fromOpaque(context).takeUnretainedValue()
                manager.schedule()
            }
            guard AXObserverCreate(app.processIdentifier,callback,&observer) == .success, let observer else { continue }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            for notification in [kAXWindowCreatedNotification,kAXUIElementDestroyedNotification,kAXWindowMiniaturizedNotification,kAXWindowDeminiaturizedNotification,kAXFocusedWindowChangedNotification,kAXMovedNotification,kAXResizedNotification] {
                _ = AXObserverAddNotification(observer,element,notification as CFString,Unmanaged.passUnretained(self).toOpaque())
            }
            CFRunLoopAddSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(observer),.commonModes)
            observers[app.processIdentifier] = observer
        }
        runningApps = apps.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    func activeID() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        guard let focused = axRead(element,kAXFocusedWindowAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        return windows.first { CFEqual($0.element,focused) }?.id
    }
    func activeDisplay() -> String? {
        if let id = activeID(), let w = windows.first(where:{$0.id == id}) { return w.display }
        let mouse = NSEvent.mouseLocation, top = NSScreen.screens.first?.frame.maxY ?? 0
        return displays.first { $0.area.contains(CGPoint(x:mouse.x,y:top-mouse.y)) }?.id ?? displays.first?.id
    }
    func refresh(force:Bool = false) {
        guard !applying, NSEvent.pressedMouseButtons == 0 else { return }
        // AX geometry and CG visibility metadata settle at different times.
        // Keep known windows during our own moves instead of dropping their IDs
        // (and Focus state) on a transient bounds mismatch. New commands can
        // still arrange that known set immediately while discovery catches up.
        if fitPending || ProcessInfo.processInfo.systemUptime < discoveryNotBefore {
            if force {
                if enabled { applyLayouts() }
                else { status = "Paused · \(windows.count) eligible windows"; menuChanged?() }
            }
            schedule(); return
        }
        trusted = AXIsProcessTrusted(); displays = connectedDisplays()
        guard trusted else { status = "Accessibility access needed"; menuChanged?(); return }
        attachObservers()
        // CG metadata only: no image capture. On-screen filtering avoids moving other Spaces.
        let visible = (CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []).filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
        let old = windows
        var found: [ManagedWindow] = []
        for app in runningApps where !app.isHidden && !excluded.contains(app.bundleIdentifier ?? "") {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(appElement,0.15)
            guard let list = axRead(appElement,kAXWindowsAttribute) as? [AXUIElement] else { continue }
            for element in list {
                guard (axRead(element,kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole,
                      !axBool(element,kAXMinimizedAttribute), !axBool(element,"AXFullScreen"), let frame = axFrame(element), frame.width > 60, frame.height > 60 else { continue }
                var canSize = DarwinBoolean(false), canMove = DarwinBoolean(false)
                guard AXUIElementIsAttributeSettable(element,kAXSizeAttribute as CFString,&canSize) == .success, canSize.boolValue,
                      AXUIElementIsAttributeSettable(element,kAXPositionAttribute as CFString,&canMove) == .success, canMove.boolValue else { continue }
                let onScreen = visible.contains { row in
                    guard (row[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier,
                          let data = row[kCGWindowBounds as String] as? [String:Any],
                          let bounds = CGRect(dictionaryRepresentation:data as CFDictionary) else { return false }
                    return abs(bounds.minX-frame.minX) < 4 && abs(bounds.minY-frame.minY) < 4 && abs(bounds.width-frame.width) < 4 && abs(bounds.height-frame.height) < 4
                }
                guard onScreen, let screen = Geometry.bestScreen(for:frame,screens:displays.map(\.area)) else { continue }
                let id: String
                if let prior = old.first(where:{CFEqual($0.element,element)}) { id = prior.id }
                else if let entry = floating.first(where:{CFEqual($0.value,element)}) { id = entry.key }
                else { nextID += 1; id = "w\(nextID)" }
                if let observer = observers[app.processIdentifier] {
                    for notification in [kAXUIElementDestroyedNotification,kAXWindowMiniaturizedNotification,kAXWindowDeminiaturizedNotification,kAXMovedNotification,kAXResizedNotification] {
                        _ = AXObserverAddNotification(observer,element,notification as CFString,Unmanaged.passUnretained(self).toOpaque())
                    }
                }
                found.append(ManagedWindow(id:id,element:element,app:app,frame:frame,display:displays[screen].id))
            }
        }
        let order = Dictionary(uniqueKeysWithValues:old.enumerated().map{($0.element.id,$0.offset)})
        windows = found.enumerated().sorted { (order[$0.element.id] ?? (old.count+$0.offset)) < (order[$1.element.id] ?? (old.count+$1.offset)) }.map(\.element)
        let live = Set(windows.map(\.id))
        floating = floating.filter { live.contains($0.key) }
        // Bound original snapshots to the live window set (never persist AX references or titles).
        originals = originals.filter { live.contains($0.key) }
        minimums = minimums.filter { live.contains($0.key) }
        settledSizes = settledSizes.filter { live.contains($0.key) }
        if let id = focusedID, !live.contains(id) { restoreFocus() }
        windowCount = windows.count
        guard enabled else { status = "Paused · \(windows.count) eligible windows"; lastSignature = ""; menuChanged?(); return }
        let active = activeID()
        if let active, states.values.contains(where:{$0.slot(of:active) != nil}) { lastActiveID = active }
        let signature = windows.filter{floating[$0.id] == nil}.map { "\($0.id)@\($0.display)" }.joined(separator:"|") + displays.map{"\($0.id):\($0.area)"}.joined()
        states = states.filter { key,_ in displays.contains{$0.id == key} }
        let changedSize = !fitPending && windows.contains { w in
            guard floating[w.id] == nil, let size = settledSizes[w.id] else { return false }
            return abs(w.frame.width-size.width)>4 || abs(w.frame.height-size.height)>4
        }
        if force || signature != lastSignature || changedSize { applyLayouts() }
        lastSignature = signature; menuChanged?()
    }
    private func applyLayouts(attempt: Int = 0) {
        guard enabled, trusted, focusedID == nil else { return }
        discoveryNotBefore = ProcessInfo.processInfo.systemUptime + 0.6
        fitCheck?.cancel(); layoutGeneration += 1; fitPending = true
        let generation = layoutGeneration
        applying = true
        var requests: [(ManagedWindow,CGRect,Bool,CGSize?)] = []
        var firstSizes: [String:CGSize] = [:]
        var retryFailures: Set<String> = []
        var probeSizes: [String:CGSize] = [:]
        var tooLarge = 0, tileCount = 0, stacked = 0
        let active = activeID()
        let focused = active.flatMap { candidate in states.values.contains(where:{$0.slot(of:candidate) != nil}) ? candidate : nil } ?? lastActiveID
        for display in displays {
            let members = windows.filter { $0.display == display.id && floating[$0.id] == nil }
            let plan = AdaptiveLayout.plan(in:display.area, windows:members.map(\.id),
                state:states[display.id] ?? TileState(), minimums:minimums,
                settings:configuration(display.id), focused:focused)
            states[display.id] = plan.state; fittedFrames[display.id] = plan.frames
            effectiveTiles[display.id] = plan.state.tiles.count
            effectiveLayouts[display.id] = plan.layout
            tileCount += plan.state.tiles.count
            stacked += max(0, members.count - plan.floating.count - plan.state.tiles.count)
            tooLarge += plan.floating.count
            for (slot,ids) in plan.state.tiles.enumerated() { for id in ids {
                guard let window = members.first(where:{$0.id == id}) else { continue }
                if originals[id] == nil { originals[id] = (window.element,window.frame) }
                let target = plan.frames[slot]
                let before = axFrame(window.element)?.size
                requests.append((window,target,axSetFrame(window.element,target),before))
            } }
            // A window larger than the entire usable display cannot share a tile.
            // Leave its accepted size intact and center it, rather than repeatedly shrinking it.
            for id in plan.floating {
                guard let w = members.first(where:{$0.id == id}), let actual = axFrame(w.element) else { continue }
                if originals[id] == nil { originals[id] = (w.element,w.frame) }
                let centered = CGRect(x:display.area.midX-actual.width/2,y:display.area.midY-actual.height/2,width:actual.width,height:actual.height)
                _ = axSetFrame(w.element,centered)
            }
        }
        applying = false
        status = "Fitting windows…"
        // Confirm a second sample before treating an accepted size as a bound.
        // Slow/animated clients can still be shrinking at the first sample.
        let check = DispatchWorkItem { [weak self] in
            guard let self, self.layoutGeneration == generation else { return }
            self.fitPending = false
            guard self.enabled, self.trusted, self.focusedID == nil else { return }
            guard NSEvent.pressedMouseButtons == 0 else { self.lastSignature = ""; self.schedule(); return }
            var learned = false, rejected = 0
            var rejectedApps: [String:Set<String>] = [:]
            func reject(_ window: ManagedWindow) {
                rejected += 1
                rejectedApps[window.display,default:[]].insert(window.app.localizedName ?? "App")
            }
            for (window,target,written,before) in requests {
                guard let actual = axFrame(window.element) else { reject(window); continue }
                if !ResizeFeedback.matches(actual,target) || !written || retryFailures.contains(window.id) { reject(window) }
                guard written, !retryFailures.contains(window.id), self.configuration(window.display).autoFit else { continue }
                let prior = self.minimums[window.id] ?? .zero
                let next = ResizeFeedback.minimum(prior:prior,target:target.size,
                    first:firstSizes[window.id],confirmed:actual.size,written:written,before:before,probe:probeSizes[window.id])
                if next != prior { self.minimums[window.id] = next; learned = true }
            }
            if learned && attempt < 8 { self.applyLayouts(attempt:attempt+1); return }
            for display in self.displays {
                let members = self.windows.filter { $0.display == display.id && self.floating[$0.id] == nil }
                let count = self.effectiveTiles[display.id] ?? 0
                if count > 0 && count < min(self.configuration(display.id).capacity,members.count) {
                    let bounds = members.compactMap { window -> String? in
                        guard let size = self.minimums[window.id], size.width > 0 || size.height > 0 else { return nil }
                        let width = size.width > 0 ? String(Int(ceil(size.width))) : "?"
                        let height = size.height > 0 ? String(Int(ceil(size.height))) : "?"
                        return "\(window.app.localizedName ?? "App"): \(width) × \(height) pt"
                    }
                    self.fittingDetails[display.id] = "Only \(count) of \(self.configuration(display.id).capacity) tiles fit the observed window sizes. Stacked windows overlap in the same tile. " +
                        (bounds.isEmpty ? "Some windows have not accepted their requested frames." : "Observed accepted sizes (? = unknown): " + bounds.joined(separator:"; "))
                } else { self.fittingDetails[display.id] = nil }
                if let names = rejectedApps[display.id], !names.isEmpty {
                    let message = "Could not place: " + names.sorted().joined(separator:", ") + ". These apps did not accept their requested frames."
                    self.fittingDetails[display.id] = [self.fittingDetails[display.id],message].compactMap{$0}.joined(separator:" ")
                }
            }
            var parts = ["Tiling · \(tileCount) \(tileCount == 1 ? "tile" : "tiles")"]
            if stacked > 0 { parts.append("\(stacked) \(stacked == 1 ? "window shares a tile" : "windows share tiles")") }
            if tooLarge > 0 { parts.append("\(tooLarge) too large for display") }
            if rejected > 0 { parts.append("\(rejected) \(rejected == 1 ? "window did" : "windows did") not reach their tiles") }
            self.settledSizes = Dictionary(uniqueKeysWithValues:self.windows.compactMap { w in axFrame(w.element).map{(w.id,$0.size)} })
            self.status = parts.joined(separator:" · "); self.menuChanged?()
        }
        let sample = DispatchWorkItem { [weak self] in
            guard let self, self.layoutGeneration == generation else { return }
            guard self.enabled, self.trusted, self.focusedID == nil, NSEvent.pressedMouseButtons == 0 else {
                self.fitPending = false; self.lastSignature = ""; self.schedule(); return
            }
            firstSizes = Dictionary(uniqueKeysWithValues:requests.compactMap { window,_,_,_ in
                axFrame(window.element).map { (window.id,$0.size) }
            })
            // Verify responsiveness before calling an unchanged dimension a
            // minimum. Probe at most 32 points larger, within this display,
            // then retry the original size without rewriting position.
            var retry: [(ManagedWindow,CGRect)] = []
            for (window,target,written,before) in requests {
                guard written, let before, let observed = firstSizes[window.id],
                      let area = self.displays.first(where:{$0.id == window.display})?.area else { continue }
                let unchangedWidth = abs(observed.width-before.width) <= 4 && abs(observed.width-target.width) > 4
                let unchangedHeight = abs(observed.height-before.height) <= 4 && abs(observed.height-target.height) > 4
                guard unchangedWidth || unchangedHeight else { continue }
                let probe = CGSize(width:unchangedWidth ? max(observed.width,min(area.width,observed.width+32)) : observed.width,
                                   height:unchangedHeight ? max(observed.height,min(area.height,observed.height+32)) : observed.height)
                if !axSetSize(window.element,probe) { retryFailures.insert(window.id) }
                retry.append((window,target))
            }
            guard !retry.isEmpty else {
                self.fitCheck = check
                DispatchQueue.main.asyncAfter(deadline:.now()+0.35,execute:check)
                return
            }
            let restore = DispatchWorkItem { [weak self] in
                guard let self, self.layoutGeneration == generation else { return }
                guard self.enabled, self.trusted, self.focusedID == nil, NSEvent.pressedMouseButtons == 0 else {
                    self.fitPending = false; self.lastSignature = ""; self.schedule(); return
                }
                for (window,target) in retry {
                    probeSizes[window.id] = axFrame(window.element)?.size
                    if !axSetSize(window.element,target.size) { retryFailures.insert(window.id) }
                }
                self.fitCheck = check
                DispatchQueue.main.asyncAfter(deadline:.now()+0.3,execute:check)
            }
            self.fitCheck = restore
            DispatchQueue.main.asyncAfter(deadline:.now()+0.05,execute:restore)
        }
        fitCheck = sample
        DispatchQueue.main.asyncAfter(deadline:.now()+0.35,execute:sample)
    }
    func previewFrames(_ id:String) -> [CGRect]? {
        guard enabled, configuration(id).autoFit, let display = displays.first(where:{$0.id == id}),
              let frames = fittedFrames[id], !frames.isEmpty else { return nil }
        return frames.map { CGRect(x:($0.minX-display.area.minX)/display.area.width,
                                   y:($0.minY-display.area.minY)/display.area.height,
                                   width:$0.width/display.area.width,height:$0.height/display.area.height) }
    }
    func tidy() { restoreFocus(); minimums = [:]; lastSignature = ""; refresh(force:true) }
    func toggleFocus() {
        if focusedID != nil { restoreFocus(); return }
        guard trusted, enabled, let id = activeID(), floating[id] == nil,
              let window = windows.first(where:{$0.id == id}), let display = displays.first(where:{$0.id == window.display}) else { return }
        focusSnapshot = Dictionary(uniqueKeysWithValues:windows.filter{$0.display == display.id}.compactMap { w in axFrame(w.element).map{(w.id,(w.element,$0))} })
        fitCheck?.cancel(); layoutGeneration += 1; fitPending = false
        focusedID = id; focusActive = true
        discoveryNotBefore = ProcessInfo.processInfo.systemUptime + 0.6
        let frame = display.area.insetBy(dx:configuration(display.id).gap,dy:configuration(display.id).gap)
        axSetFrame(window.element,frame); activate(id)
    }
    func restoreFocus() {
        guard focusedID != nil else { return }
        focusedID = nil; focusActive = false; lastSignature = ""
        discoveryNotBefore = ProcessInfo.processInfo.systemUptime + 0.6
        for (_,snapshot) in focusSnapshot { axSetFrame(snapshot.0,snapshot.1) }
        focusSnapshot = [:]
    }
    func restoreOriginals() {
        enabled = false
        discoveryNotBefore = ProcessInfo.processInfo.systemUptime + 0.6
        for (_,snapshot) in originals { axSetFrame(snapshot.0,snapshot.1) }
        originals = [:]; lastSignature = ""
    }
    func toggleFloat() {
        guard let id = activeID(), let window = windows.first(where:{$0.id == id}) else { return }
        restoreFocus()
        if floating[id] != nil { floating.removeValue(forKey:id) } else { floating[id] = window.element }
        refresh(force:true)
    }
    func activate(_ id:String) {
        guard let w = windows.first(where:{$0.id == id}) else { return }
        w.app.activate(options:.activateIgnoringOtherApps)
        _ = AXUIElementSetAttributeValue(AXUIElementCreateApplication(w.app.processIdentifier),kAXFocusedWindowAttribute as CFString,w.element)
        _ = AXUIElementPerformAction(w.element,kAXRaiseAction as CFString)
    }
    func cycleStack() {
        guard enabled, let id = activeID(), let w = windows.first(where:{$0.id == id}), let next = states[w.display]?.next(in:id) else { return }
        restoreFocus(); activate(next)
    }
    func cycleWindow(_ offset:Int) {
        guard enabled, let id = activeID(), let w = windows.first(where:{$0.id == id}) else { return }
        let list = windows.filter{$0.display == w.display && floating[$0.id] == nil}
        guard !list.isEmpty, let i = list.firstIndex(where:{$0.id == id}) else { return }
        restoreFocus(); activate(list[(i+offset+list.count)%list.count].id)
    }
    func makePrimary() {
        guard enabled, let id = activeID(), let w = windows.first(where:{$0.id == id}), let first = states[w.display]?.tiles.first?.first else { return }
        restoreFocus(); states[w.display]?.swap(id,first); applyLayouts(); activate(id)
    }
    func swap(direction:CGPoint) {
        guard enabled, let id = activeID(), let w = windows.first(where:{$0.id == id}), let state = states[w.display], let slot = state.slot(of:id), let display = displays.first(where:{$0.id == w.display}) else { return }
        let frames = fittedFrames[w.display] ?? Geometry.frames(in:display.area,count:state.tiles.count,settings:configuration(w.display))
        let origin = CGPoint(x:frames[slot].midX,y:frames[slot].midY)
        let candidates = frames.indices.filter { i in
            let dx = frames[i].midX-origin.x, dy = frames[i].midY-origin.y
            return i != slot && dx*direction.x+dy*direction.y > 1
        }.sorted { a,b in
            let da = hypot(frames[a].midX-origin.x,frames[a].midY-origin.y)
            let db = hypot(frames[b].midX-origin.x,frames[b].midY-origin.y)
            return da < db
        }
        guard let target = candidates.first, let other = state.tiles[target].last else { return }
        restoreFocus(); states[w.display]?.swap(id,other); applyLayouts(); activate(id)
    }
    func shutdown() {
        timer?.invalidate(); pending?.cancel(); fitCheck?.cancel(); layoutGeneration += 1; restoreFocus()
        for (_,o) in observers { CFRunLoopRemoveSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(o),.commonModes) }
        for t in tokens { NSWorkspace.shared.notificationCenter.removeObserver(t); NotificationCenter.default.removeObserver(t) }
    }
}
