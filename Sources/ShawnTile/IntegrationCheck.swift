// Deterministic real AX checks against disposable windows in a child process.
// Only that PID is visible to the manager; ordinary desktop windows are excluded.
import AppKit
import TileCore

final class DelayedFixtureWindow: NSWindow {
    var delaysResizing = false
    var ignoredWidthRequests = 0
    var ignoresSmallHeightGrowth = false
    private var resizeGeneration = 0
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        if ignoresSmallHeightGrowth && frameRect.height > frame.height && frameRect.height-frame.height <= 33 {
            super.setFrame(NSRect(origin:frameRect.origin,size:NSSize(width:frameRect.width,height:frame.height)),display:flag)
            return
        }
        if ignoredWidthRequests > 0 && abs(frameRect.width-frame.width) > 4 {
            ignoredWidthRequests -= 1
            super.setFrame(NSRect(origin:frameRect.origin,size:NSSize(width:frame.width,height:frameRect.height)),display:flag)
            return
        }
        let size = frameRect.size
        guard delaysResizing, size != frame.size else { super.setFrame(frameRect,display:flag); return }
        resizeGeneration += 1
        let generation = resizeGeneration, start = frame.size
        // Simulate a client which acknowledges AX immediately but animates
        // through two oversized intermediate frames before reaching the target.
        for (delay, fraction) in [(0.2, CGFloat(0.25)), (0.5, CGFloat(0.6)), (0.85, CGFloat(1))] {
            DispatchQueue.main.asyncAfter(deadline:.now()+delay) { [weak self] in
                guard let self, self.resizeGeneration == generation else { return }
                self.applySize(NSSize(width:start.width+(size.width-start.width)*fraction,
                                      height:start.height+(size.height-start.height)*fraction))
            }
        }
    }
    private func applySize(_ size:NSSize) { super.setFrame(NSRect(origin:frame.origin,size:size),display:true) }
}

final class FixtureDelegate:NSObject,NSApplicationDelegate {
    var windows:[NSWindow] = []
    var observedSizes:[NSSize] = []
    var timer:Timer?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.regular)
        for i in 0..<5 {
            let window = DelayedFixtureWindow(contentRect:NSRect(x:100+i*25,y:100+i*25,width:500,height:400),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
            window.title = "Shawn Tile test \(i+1)"; window.isReleasedWhenClosed = false
            window.minSize = NSSize(width:100,height:100)
            let label = NSTextField(labelWithString:"Disposable window \(i+1) — closes after verification")
            label.frame = NSRect(x:20,y:100,width:450,height:40); window.contentView?.addSubview(label)
            window.makeKeyAndOrderFront(nil); windows.append(window)
        }
        NSApp.activate(ignoringOtherApps:true)
        // Commands operate only on these controlled fixture windows.
        FileHandle.standardInput.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { DispatchQueue.main.async { NSApp.terminate(nil) }; return }
            let text = String(data:data,encoding:.utf8) ?? ""
            DispatchQueue.main.async {
                for command in text.split(separator:"\n") {
                    switch command {
                    case "smallHeightProbe":
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:870)
                        for case let window as DelayedFixtureWindow in self.windows {
                            window.delaysResizing = false; window.ignoredWidthRequests = 0
                            window.ignoresSmallHeightGrowth = false
                            window.minSize = NSSize(width:100,height:area.height*0.65)
                            window.setFrame(NSRect(x:area.minX,y:area.minY,width:500,height:area.height*0.65),display:true)
                            window.ignoresSmallHeightGrowth = true
                        }
                    case "retry", "ignored":
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:870)
                        for case let window as DelayedFixtureWindow in self.windows {
                            window.delaysResizing = false; window.ignoredWidthRequests = 0
                            window.ignoresSmallHeightGrowth = false; window.minSize = NSSize(width:100,height:100)
                            window.setFrame(area,display:true)
                            window.ignoredWidthRequests = command == "retry" ? 1 : 100
                        }
                    case "delayed":
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:870)
                        for window in self.windows {
                            window.setFrame(area,display:true)
                            (window as? DelayedFixtureWindow)?.delaysResizing = true
                        }
                    case "close": self.windows.last(where:{$0.isVisible})?.close()
                    case "minimize": self.windows.first(where:{$0.isVisible && !$0.isMiniaturized})?.miniaturize(nil)
                    case "restore": self.windows.first(where:{$0.isMiniaturized})?.deminiaturize(nil)
                    case "large":
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1600,height:1000)
                        for window in self.windows where window.isVisible { window.minSize = NSSize(width:area.width*0.62,height:area.height*0.62) }
                    case "mixed":
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1600,height:1000)
                        for (index,window) in self.windows.enumerated() where window.isVisible {
                            window.minSize = NSSize(width:100,height:(index == 2 || index == 3) ? area.height*0.65 : 100)
                        }
                    case "tall":
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1600,height:1000)
                        for window in self.windows where window.isVisible { window.minSize = NSSize(width:100,height:area.height*0.65) }
                    case "fullHeight":
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1600,height:1000)
                        for window in self.windows where window.isVisible { window.minSize = NSSize(width:100,height:area.height) }
                    case "regroup":
                        for window in self.windows { window.close() }
                        self.windows = []
                        let area = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1600,height:1000)
                        let ratios:[(CGFloat,CGFloat)] = [(0.6,0.38),(0.16,0.15),(0.35,0.38),(0.35,0.38),(0.35,0.65),(0.16,0.65)]
                        for (index,ratio) in ratios.enumerated() {
                            let window = NSWindow(contentRect:NSRect(x:100+index*20,y:100,width:400,height:300),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
                            window.title = "Shawn Tile regrouping \(index+1)"; window.minSize = NSSize(width:area.width*ratio.0,height:area.height*ratio.1); window.isReleasedWhenClosed = false
                            window.makeKeyAndOrderFront(nil); self.windows.append(window)
                        }
                    case "replace":
                        for window in self.windows { window.close() }
                        self.windows = []
                        for i in 0..<4 {
                            let window = NSWindow(contentRect:NSRect(x:100+i*20,y:100,width:400,height:300),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
                            window.title = "Shawn Tile replacement \(i+1)"; window.minSize = NSSize(width:100,height:100); window.isReleasedWhenClosed = false
                            window.makeKeyAndOrderFront(nil); self.windows.append(window)
                        }
                    case "quit": NSApp.terminate(nil)
                    default: break
                    }
                }
            }
        }
    }
}
func runFixture() {
    let app = NSApplication.shared, delegate = FixtureDelegate()
    app.delegate = delegate; withExtendedLifetime(delegate) { app.run() }
}
func runIntegration() {
    signal(SIGPIPE,SIG_IGN)
    guard AXIsProcessTrusted() else {
        print("SKIP: real window integration requires Accessibility for this process. No windows were moved.")
        return
    }
    let child = Process(), pipe = Pipe()
    child.executableURL = URL(fileURLWithPath:CommandLine.arguments[0]); child.arguments = ["--fixture"]; child.standardInput = pipe
    do { try child.run() } catch { print("FAIL: fixture launch: \(error)"); exit(1) }
    let domain = "com.shawnwright.ShawnTile.Checks.\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName:domain)!
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    var manager:WindowManager?
    var failures:[String] = [], count = 0
    func check(_ result:Bool,_ name:String) {
        count += 1; print("\(result ? "PASS" : "FAIL"): \(name)"); if !result { failures.append(name) }
    }
    func send(_ command:String) { try? pipe.fileHandleForWriting.write(contentsOf:Data((command+"\n").utf8)) }
    func later(_ seconds:Double,_ block:@escaping ()->Void) { DispatchQueue.main.asyncAfter(deadline:.now()+seconds,execute:block) }
    later(2) {
        let m = WindowManager(preferences:preferences,onlyPID:child.processIdentifier); manager = m
        check(m.windows.count == 5,"discover five fixture windows and exclude all other apps")
        guard m.windows.count == 5 else { m.shutdown(); if child.isRunning { child.terminate() }; exit(1) }
        guard let screen = m.displays.first else { failures.append("no display"); app.stop(nil); return }
        m.update(screen.id) { $0.capacity = 3; $0.gap = 10; $0.layout = .grid }
        m.enabled = true
        later(1) {
            let actual = m.windows.compactMap{axFrame($0.element)}
            let unique = Set(actual.map{NSStringFromRect($0)})
            check(actual.count == 5 && unique.count == 3,"real Accessibility positions five windows into three tiles")
            let expected = Geometry.frames(in:screen.area,count:3,settings:m.configuration(screen.id))
            check(actual.allSatisfy { a in expected.contains { abs(a.minX-$0.minX)<4 && abs(a.minY-$0.minY)<4 && abs(a.width-$0.width)<4 && abs(a.height-$0.height)<4 } },"actual bounds match layout engine")
            m.update(screen.id) { $0.capacity = 4 }
            later(0.8) {
                check(Set(m.windows.compactMap{axFrame($0.element)}.map{NSStringFromRect($0)}).count == 4,"capacity increase promotes overflow")
                m.activate(m.windows[0].id)
                later(0.5) {
                    let id = m.windows[0].id
                    let before = axFrame(m.windows[0].element)
                    check(m.activeID() == id,"active-window lookup selects requested fixture")
                    m.toggleFocus()
                    later(0.5) {
                        check(m.focusActive && (axFrame(m.windows[0].element)?.width ?? 0) > screen.area.width*0.8,"Focus expands selected window")
                        m.restoreFocus()
                        check(axFrame(m.windows.first(where:{$0.id == id})!.element) == before,"Focus restores exact prior bounds")
                        send("close")
                        // A pending responsiveness check can defer discovery for
                        // 1.05 seconds; allow it to finish before checking removal.
                        later(2) {
                            m.refresh(force:true); check(m.windows.count == 4,"closed window disappears and survivors reflow")
                            send("minimize")
                            later(2.0) {
                                m.refresh(force:true); check(m.windows.count == 3,"minimized window excluded")
                                send("restore")
                                later(2.0) {
                                    m.refresh(force:true); check(m.windows.count == 4,"restored window rejoins")
                                    m.restoreOriginals(); check(!m.enabled,"restore originals pauses tiling")
                                    send("large")
                                    later(0.5) {
                                        m.enabled = true; m.update(screen.id) { $0.capacity = 4; $0.autoFit = true }
                                        later(2.5) {
                                            let frames = m.windows.compactMap { axFrame($0.element) }
                                            check(m.effectiveTiles[screen.id] == 1 && Set(frames.map{NSStringFromRect($0)}).count == 1,"automatically stack oversized tile candidates without changing configured capacity")
                                            check(m.configuration(screen.id).capacity == 4,"automatic fitting preserves user's maximum tile preference")
                                            check(frames.allSatisfy { screen.area.insetBy(dx:-2,dy:-2).contains($0) },"accepted real window frames stay inside the display")
                                            send("fullHeight")
                                            later(0.5) {
                                                m.update(screen.id) { $0.layout = .automatic }; m.tidy()
                                                later(2) {
                                                    let full = m.windows.compactMap { axFrame($0.element) }
                                                    check(m.effectiveTiles[screen.id] == 4 && full.allSatisfy{abs($0.height-screen.area.height)<2},"automatic gap reduction fits full-height window minimums")
                                                    check(m.configuration(screen.id).gap == 10,"automatic gap reduction preserves preferred spacing")
                                                    send("replace")
                                                    later(2.5) {
                                                m.refresh()
                                                later(0.7) {
                                                    check(m.windows.count == 4 && m.effectiveTiles[screen.id] == 4,"automatically restore four tiles after restrictive windows close")
                                                    check(Set(m.windows.compactMap{axFrame($0.element)}.map{NSStringFromRect($0)}).count == 4,"replacement windows occupy four distinct tiles")
                                                    m.enabled = false; m.shutdown(); send("quit"); preferences.removePersistentDomain(forName:domain)
                                                    print("INTEGRATION: \(count) checks, \(failures.count) failures; fixture PID \(child.processIdentifier) only")
                                                    if child.isRunning { child.terminate() }
                                                    exit(failures.isEmpty ? 0 : 1)
                                                }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    later(35) { manager?.shutdown(); if child.isRunning { child.terminate() }; preferences.removePersistentDomain(forName:domain); print("FAIL: integration timeout"); exit(1) }
    app.run()
    if child.isRunning { child.terminate() }
    preferences.removePersistentDomain(forName:domain)
    exit(failures.isEmpty ? 0 : 1)
}
