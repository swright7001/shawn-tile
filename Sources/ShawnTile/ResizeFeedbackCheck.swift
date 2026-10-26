import AppKit
import TileCore

func runResizeFeedbackChecksNative() {
    setbuf(stdout,nil); signal(SIGPIPE,SIG_IGN)
    guard AXIsProcessTrusted() else { print("SKIP: resize checks require Accessibility"); exit(2) }
    let child = Process(), pipe = Pipe()
    child.executableURL = URL(fileURLWithPath:CommandLine.arguments[0])
    child.arguments = ["--fixture"]; child.standardInput = pipe
    do { try child.run() } catch { print("FAIL: fixture launch"); exit(1) }
    let domain = "com.shawnwright.ShawnTile.ResizeChecks.\(UUID().uuidString)"
    let prefs = UserDefaults(suiteName:domain)!, app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    var manager:WindowManager?
    func finish(_ passed:Bool) {
        manager?.enabled = false; manager?.shutdown()
        if child.isRunning { child.terminate() }
        prefs.removePersistentDomain(forName:domain)
        print("\(passed ? "PASS" : "FAIL"): delayed AX resize retains four Grid tiles; fixture PID only")
        exit(passed ? 0 : 1)
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+2) {
        try? pipe.fileHandleForWriting.write(contentsOf:Data("delayed\n".utf8))
        DispatchQueue.main.asyncAfter(deadline:.now()+0.5) {
            let m = WindowManager(preferences:prefs,onlyPID:child.processIdentifier); manager = m
            guard m.windows.count == 5, let display = m.displays.first else { finish(false); return }
            m.update(display.id) { $0.layout = .grid; $0.capacity = 4; $0.gap = 4 }
            m.enabled = true
            DispatchQueue.main.asyncAfter(deadline:.now()+6) {
                let frames = m.windows.compactMap { axFrame($0.element) }
                let expected = Geometry.frames(in:display.area,count:4,settings:m.configuration(display.id))
                finish(m.effectiveTiles[display.id] == 4 && frames.count == 5 && frames.allSatisfy { actual in
                    expected.contains { ResizeFeedback.matches(actual,$0) }
                })
            }
        }
    }
    DispatchQueue.main.asyncAfter(deadline:.now()+15) { finish(false) }
    app.run()
}
