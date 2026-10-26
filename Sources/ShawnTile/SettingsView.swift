import SwiftUI
import ServiceManagement
import TileCore

struct LayoutPreview: View {
    var config: DisplaySettings
    var normalizedFrames: [CGRect]? = nil
    var body: some View {
        GeometryReader { geometry in
            let frames = normalizedFrames.map { normalized in normalized.map { r in
                CGRect(x:r.minX*geometry.size.width,y:r.minY*geometry.size.height,width:r.width*geometry.size.width,height:r.height*geometry.size.height)
            } } ?? Geometry.frames(in:CGRect(origin:.zero,size:geometry.size),count:config.capacity,settings:config)
            ForEach(Array(frames.enumerated()),id:\.offset) { i,r in
                RoundedRectangle(cornerRadius:8).fill(i == 0 ? Color.cyan.opacity(0.8) : Color.blue.opacity(0.20 + Double(i)*0.12))
                    .overlay(Text("\(i+1)").font(.system(size:18,weight:.semibold,design:.rounded)).foregroundStyle(.white))
                    .frame(width:r.width,height:r.height).position(x:r.midX,y:r.midY)
            }
        }.frame(height:150).background(Color.black.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius:14))
        .accessibilityLabel("\(config.layout.rawValue), \(normalizedFrames?.count ?? config.capacity) tiles")
    }
}
struct SettingsView: View {
    @ObservedObject var manager:WindowManager
    @State private var selected = ""
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError = ""
    private var current:String { manager.displays.contains(where:{$0.id == selected}) ? selected : manager.displays.first?.id ?? "" }
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack(spacing:14) {
                Image(systemName:"rectangle.split.2x2.fill").font(.system(size:34)).foregroundStyle(.cyan)
                VStack(alignment:.leading,spacing:3) {
                    Text("Shawn Tile").font(.system(size:25,weight:.bold,design:.rounded))
                    Text("A little order for your desktop.").foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Automatic tiling",isOn:$manager.enabled).toggleStyle(.switch).fixedSize()
                    .disabled(!manager.trusted)
            }
            HStack {
                Circle().fill(manager.trusted ? (manager.enabled ? Color.green : .orange) : .orange).frame(width:7,height:7)
                Text(manager.status).font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Tidy now") { manager.tidy() }.disabled(!manager.trusted || !manager.enabled)
            }
            if !manager.trusted {
                HStack(alignment:.top) {
                    Image(systemName:"hand.raised.fill").foregroundStyle(.orange)
                    VStack(alignment:.leading,spacing:5) {
                        Text("Allow Accessibility to arrange windows").fontWeight(.semibold)
                        Text("Enable Shawn Tile in Privacy & Security → Accessibility (Device Control & Data Access on newer macOS). This app uses window geometry and app identity, and stores no window titles.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                        Button("Open permission settings") { manager.requestPermission() }
                    }
                }.padding(14).background(Color.orange.opacity(0.09),in:RoundedRectangle(cornerRadius:12))
            }
            TabView {
                VStack(alignment:.leading,spacing:16) {
                    Picker("Display",selection:Binding(get:{current},set:{selected=$0})) {
                        ForEach(manager.displays) { Text($0.name).tag($0.id) }
                    }
                    LayoutPreview(config:manager.configuration(current),normalizedFrames:manager.previewFrames(current))
                    HStack {
                        Picker("Layout",selection:Binding(get:{manager.configuration(current).layout},set:{ value in manager.update(current){$0.layout=value} })) {
                            ForEach(Layout.allCases,id:\.self) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        Picker("Max tiles",selection:Binding(get:{manager.configuration(current).capacity},set:{ value in manager.update(current){$0.capacity=value} })) {
                            ForEach(1...4,id:\.self) { Text("\($0)").tag($0) }
                        }.frame(width:130)
                    }
                    HStack {
                        Text("Max spacing")
                        Slider(value:Binding(get:{manager.configuration(current).gap},set:{ value in manager.update(current){$0.gap=value} }),in:0...32,step:2)
                        Text("\(Int(manager.configuration(current).gap)) pt").monospacedDigit().frame(width:40)
                    }
                    Toggle("Automatically fit windows",isOn:Binding(get:{manager.configuration(current).autoFit},set:{ value in manager.update(current){$0.autoFit=value} }))
                    Text("Splits and spacing adapt to your apps. Extra windows stack when fewer tiles fit. Up to \(manager.configuration(current).capacity) tiles; \(manager.effectiveTiles[current] ?? 0) currently in use.").font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
                }.padding(18).tabItem { Label("Layout",systemImage:"rectangle.split.2x2") }
                VStack(alignment:.leading,spacing:10) {
                    Text("Choose apps to leave floating").fontWeight(.semibold)
                    ScrollView {
                        VStack(alignment:.leading,spacing:9) {
                            ForEach(manager.runningApps,id:\.processIdentifier) { app in
                                if let bundle = app.bundleIdentifier {
                                    Toggle(app.localizedName ?? bundle,isOn:Binding(get:{manager.excluded.contains(bundle)},set:{ _ in manager.exclude(bundle) }))
                                }
                            }
                            let missing = manager.excluded.subtracting(Set(manager.runningApps.compactMap(\.bundleIdentifier))).sorted()
                            ForEach(missing,id:\.self) { bundle in
                                HStack { Text(bundle).foregroundStyle(.secondary); Spacer(); Button("Remove") { manager.exclude(bundle) } }
                            }
                        }
                    }
                }.padding(18).tabItem { Label("Exclusions",systemImage:"app.badge.checkmark") }
                VStack(alignment:.leading,spacing:9) {
                    shortcut("1–4 tiles","⌃⌥⌘ 1–4")
                    shortcut("Focus / restore","⌃⌥ Z")
                    shortcut("Float / tile window","⌃⌥ F")
                    shortcut("Cycle stack","⌃⌥ `")
                    shortcut("Previous / next window","⌃⌥ [ / ]")
                    shortcut("Swap tiles","⌃⌥ Arrow keys")
                    shortcut("Make primary","⌃⌥ Return")
                    shortcut("Pause / resume","⌃⌥ P")
                    Text(manager.shortcutErrors.isEmpty ? "Shortcuts registered with macOS. No keyboard recording." : manager.shortcutErrors.joined(separator:"\n"))
                        .font(.caption).foregroundStyle(manager.shortcutErrors.isEmpty ? Color.secondary : .orange)
                }.padding(18).tabItem { Label("Keyboard",systemImage:"keyboard") }
                VStack(alignment:.leading,spacing:16) {
                    Toggle("Open at login",isOn:Binding(get:{loginEnabled},set:{ value in
                        do { if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginEnabled = SMAppService.mainApp.status == .enabled; loginError = loginEnabled == value ? "" : "Approve Shawn Tile under Login Items in System Settings."
                        } catch { loginError = error.localizedDescription }
                    }))
                    if !loginError.isEmpty { Text(loginError).font(.callout).foregroundStyle(.orange) }
                    Text("Your layout and exclusions are stored locally. No account, analytics, subscriptions, or network requests.").foregroundStyle(.secondary)
                    Button("Pause and restore pre-tiling positions") { manager.restoreOriginals() }
                    Text("Restores windows still visible from this session. Quit leaves ordinary tiled windows in place. Pause when using Stage Manager or another window manager.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text("Shawn Tile 0.2.1 · Original software for Shawn Wright").font(.caption)
                    Text("Inspired by automatic tiling workflows. Independent of Shoji.").font(.caption).foregroundStyle(.secondary)
                }.padding(18).tabItem { Label("General",systemImage:"gearshape") }
            }.frame(height:380)
        }.padding(24).frame(width:620).preferredColorScheme(.dark)
    }
    private func shortcut(_ name:String,_ keys:String) -> some View {
        HStack { Text(name); Spacer(); Text(keys).font(.system(.body,design:.monospaced)).foregroundStyle(.cyan) }
    }
}
