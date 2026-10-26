import AppKit
import TileCore

func runLayoutModeChecks() {
    setbuf(stdout,nil); signal(SIGPIPE,SIG_IGN)
    guard AXIsProcessTrusted() else { print("SKIP: layout mode checks require Accessibility."); exit(2) }
    let child = Process(), pipe = Pipe()
    child.executableURL = URL(fileURLWithPath:CommandLine.arguments[0]); child.arguments = ["--fixture"]; child.standardInput = pipe
    do { try child.run() } catch { print("FAIL: fixture launch"); exit(1) }
    let domain = "com.shawnwright.ShawnTile.LayoutModes.\(UUID().uuidString)", app = NSApplication.shared
    let prefs = UserDefaults(suiteName:domain)!
    app.setActivationPolicy(.accessory)
    var manager:WindowManager?, failures = 0, count = 0
    func check(_ valid:Bool,_ label:String) { count += 1; if !valid { failures += 1 }; print("\(valid ? "PASS" : "FAIL"): \(label)") }
    func finish() {
        manager?.enabled = false; manager?.shutdown(); if child.isRunning { child.terminate() }
        prefs.removePersistentDomain(forName:domain)
        print("LAYOUT MODES: \(count) checks, \(failures) failures; fixture PID \(child.processIdentifier) only")
        exit(failures == 0 ? 0 : 1)
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+2) {
        let m = WindowManager(preferences:prefs,onlyPID:child.processIdentifier); manager = m
        check(m.windows.count == 5,"discover five disposable windows")
        guard m.windows.count == 5, let display = m.displays.first else { finish(); return }
        m.update(display.id) { $0.capacity = 4; $0.gap = 10; $0.autoFit = true }; m.enabled = true
        var steps:[(String,Double,()->Void,()->Bool)] = []
        func add(_ name:String,_ wait:Double = 0.9,_ action:@escaping ()->Void,_ verify:@escaping ()->Bool) { steps.append((name,wait,action,verify)) }
        for mode in [Layout.grid,.rows,.columns,.grid,.rows] {
            add("\(mode.rawValue) arranges real windows and remains selected",0.9,{
                m.update(display.id) { $0.layout = mode }
            },{
                let actual = m.windows.compactMap{axFrame($0.element)}
                let expected = Geometry.frames(in:display.area,count:4,settings:m.configuration(display.id))
                return m.configuration(display.id).layout == mode && m.effectiveLayouts[display.id] == mode && m.effectiveTiles[display.id] == 4 &&
                    actual.count == 5 && Set(actual.map{NSStringFromRect($0)}).count == 4 && actual.allSatisfy { frame in
                        expected.contains { abs(frame.minX-$0.minX)<3 && abs(frame.minY-$0.minY)<3 && abs(frame.width-$0.width)<3 && abs(frame.height-$0.height)<3 }
                    }
            })
        }
        add("impose mixed minimums on fixture windows",0.6,{
            try? pipe.fileHandleForWriting.write(contentsOf:Data("mixed\n".utf8))
        },{true})
        add("Grid rebalances stacks to preserve four fitting tiles",2.1,{
            m.update(display.id) { $0.layout = .grid }; m.tidy()
        },{m.effectiveLayouts[display.id] == .grid && m.effectiveTiles[display.id] == 4})
        add("impose tall-only minimums on fixture windows",0.6,{
            try? pipe.fileHandleForWriting.write(contentsOf:Data("tall\n".utf8))
        },{true})
        for (mode,tiles) in [(Layout.grid,2),(.rows,1),(.columns,4),(.automatic,4)] {
            add("\(mode.rawValue) honors shape and stacks constrained windows",2.1,{
                m.update(display.id) { $0.layout = mode }; m.tidy()
            },{
                let expected:Layout = mode == .automatic ? .columns : mode
                return m.effectiveLayouts[display.id] == expected && m.effectiveTiles[display.id] == tiles && m.configuration(display.id).capacity == 4 &&
                    m.windows.compactMap{axFrame($0.element)}.allSatisfy{display.area.insetBy(dx:-3,dy:-3).contains($0)}
            })
        }
        add("replace constrained windows",1,{
            try? pipe.fileHandleForWriting.write(contentsOf:Data("replace\n".utf8))
        },{true})
        add("Grid recovers four tiles after replacement",2.1,{
            m.update(display.id) { $0.layout = .grid }; m.tidy()
        },{m.windows.count == 4 && m.effectiveTiles[display.id] == 4 && m.effectiveLayouts[display.id] == .grid})
        add("replace with six windows of different minimum sizes",1,{
            try? pipe.fileHandleForWriting.write(contentsOf:Data("regroup\n".utf8))
        },{m.windows.count == 6})
        for mode in [Layout.grid,.rows,.grid,.rows,.grid] {
            add("six-window \(mode.rawValue) regroups after layout switches",2.1,{
                m.update(display.id) { $0.layout = mode }
            },{
                let actual = m.windows.compactMap{axFrame($0.element)}
                return m.effectiveLayouts[display.id] == mode && m.effectiveTiles[display.id] == (mode == .grid ? 4 : 2) &&
                    actual.count == 6 && actual.allSatisfy{display.area.insetBy(dx:-3,dy:-3).contains($0)}
            })
        }
        var index = 0
        func next() {
            guard index < steps.count else { finish(); return }
            let step = steps[index]; index += 1; step.2()
            DispatchQueue.main.asyncAfter(deadline:.now()+step.1) { check(step.3(),step.0); next() }
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.8) { next() }
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+45) { check(false,"layout mode timeout"); finish() }
    app.run()
}
