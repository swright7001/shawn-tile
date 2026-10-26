import AppKit
import SwiftUI
import TileCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var manager:WindowManager!
    var hotKeys:HotKeys?
    var statusItem:NSStatusItem!
    var settingsWindow:NSWindow?
    var menuIsOpen = false
    var smokeDomain:String?
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.accessory)
        if CommandLine.arguments.contains("--smoke-test") {
            let domain = "com.shawnwright.ShawnTile.Smoke.\(UUID().uuidString)"
            smokeDomain = domain; manager = WindowManager(preferences:UserDefaults(suiteName:domain)!)
        } else { manager = WindowManager() }
        hotKeys = HotKeys(manager:manager)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName:"rectangle.split.2x2",accessibilityDescription:"Shawn Tile")
        statusItem.button?.toolTip = "Shawn Tile — automatic window tiling"
        rebuildMenu()
        manager.menuChanged = { [weak self] in if self?.menuIsOpen == false { self?.rebuildMenu() } }
        if CommandLine.arguments.contains("--smoke-test") {
            showSettings()
            print("SMOKE: app launched; displays=\(manager.displays.count); accessibility=\(manager.trusted); shortcuts_failed=\(manager.shortcutErrors.count)")
            DispatchQueue.main.asyncAfter(deadline:.now()+0.3) {
                print("SMOKE: posted_hotkey_status=\(self.hotKeys?.postSmokeEvent() ?? -1)")
            }
            DispatchQueue.main.asyncAfter(deadline:.now()+3) {
                print("SMOKE: settings_visible=\(self.settingsWindow?.isVisible == true); menu_items=\(self.statusItem.menu?.items.count ?? 0)")
                let capacity = self.manager.activeDisplay().map { self.manager.configuration($0).capacity } ?? 0
                print("SMOKE: hotkey_handler_capacity=\(capacity); expected=1")
                NSApp.terminate(nil)
            }
        } else if !UserDefaults.standard.bool(forKey:"onboarded") || CommandLine.arguments.contains("--settings") {
            showSettings(); UserDefaults.standard.set(true,forKey:"onboarded")
        }
    }
    func menuWillOpen(_ menu:NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu:NSMenu) { menuIsOpen = false }
    func rebuildMenu() {
        let menu = NSMenu(); menu.delegate = self
        item(manager.status,menu,enabled:false)
        item(manager.enabled ? "Pause automatic tiling" : "Enable automatic tiling",menu,action:#selector(toggle),key:"p")
        if !manager.trusted { item("Grant Accessibility…",menu,action:#selector(permission)) }
        menu.addItem(.separator())
        for display in manager.displays {
            let parent = NSMenuItem(title:display.name,action:nil,keyEquivalent:"")
            let sub = NSMenu(); let config = manager.configuration(display.id)
            for layout in Layout.allCases {
                let entry = NSMenuItem(title:layout.rawValue.capitalized,action:#selector(layoutAction(_:)),keyEquivalent:"")
                entry.target = self; entry.representedObject = [display.id,layout.rawValue]; entry.state = layout == config.layout ? .on : .off; sub.addItem(entry)
            }
            sub.addItem(.separator())
            for count in 1...4 {
                let entry = NSMenuItem(title:"\(count) tiles",action:#selector(countAction(_:)),keyEquivalent:"")
                entry.target = self; entry.representedObject = [display.id,String(count)]; entry.state = config.capacity == count ? .on : .off; sub.addItem(entry)
            }
            parent.submenu = sub; menu.addItem(parent)
        }
        menu.addItem(.separator())
        item("Tidy now",menu,action:#selector(tidy))
        item("Focus active window / restore",menu,action:#selector(focus))
        item("Float active window / tile again",menu,action:#selector(floatWindow))
        item("Next window in stack",menu,action:#selector(stack))
        let list = NSMenuItem(title:"Windows",action:nil,keyEquivalent:""); let sub = NSMenu()
        for w in manager.windows {
            let entry = NSMenuItem(title:"\(w.app.localizedName ?? "App") · \(w.id)",action:#selector(activateWindow(_:)),keyEquivalent:"")
            entry.representedObject = w.id; entry.target = self; sub.addItem(entry)
        }
        list.submenu = sub; menu.addItem(list)
        menu.addItem(.separator())
        item("Settings…",menu,action:#selector(showSettings),key:",")
        item("Pause and restore original positions",menu,action:#selector(restore))
        item("Quit Shawn Tile",menu,action:#selector(quit),key:"q")
        statusItem.menu = menu
    }
    @discardableResult func item(_ title:String,_ menu:NSMenu,action:Selector? = nil,key:String = "",enabled:Bool = true) -> NSMenuItem {
        let i = NSMenuItem(title:title,action:action,keyEquivalent:key); i.target = self; i.isEnabled = enabled; menu.addItem(i); return i
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect:NSRect(x:0,y:0,width:668,height:510),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            window.title = "Shawn Tile"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView:SettingsView(manager:manager)); window.center(); settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    @objc func toggle() { manager.enabled.toggle(); if !manager.trusted { showSettings() } }
    @objc func permission() { manager.requestPermission() }
    @objc func tidy() { manager.tidy() }
    @objc func focus() { manager.toggleFocus() }
    @objc func floatWindow() { manager.toggleFloat() }
    @objc func stack() { manager.cycleStack() }
    @objc func restore() { manager.restoreOriginals() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func activateWindow(_ sender:NSMenuItem) { if let id = sender.representedObject as? String { manager.activate(id) } }
    @objc func layoutAction(_ sender:NSMenuItem) {
        guard let value = sender.representedObject as? [String], let layout = Layout(rawValue:value[1]) else { return }; manager.update(value[0]){$0.layout=layout}
    }
    @objc func countAction(_ sender:NSMenuItem) {
        guard let value = sender.representedObject as? [String], let count = Int(value[1]) else { return }; manager.update(value[0]){$0.capacity=count}
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool) -> Bool { showSettings(); return true }
    func applicationWillTerminate(_ notification:Notification) { manager.shutdown(); hotKeys = nil; if let smokeDomain { UserDefaults.standard.removePersistentDomain(forName:smokeDomain) } }
}
if CommandLine.arguments.contains("--fixture") {
    runFixture()
} else if CommandLine.arguments.contains("--integration-test") {
    runIntegration()
} else if CommandLine.arguments.contains("--diagnostics") {
    let displays = connectedDisplays()
    print("Shawn Tile 0.2.1 | \(ProcessInfo.processInfo.operatingSystemVersionString)")
    print("Accessibility: \(AXIsProcessTrusted()) | displays: \(displays.count)")
    for display in displays { print("\(display.name): \(display.area)") }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
