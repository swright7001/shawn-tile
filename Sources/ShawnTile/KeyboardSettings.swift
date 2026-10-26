import SwiftUI
import TileCore

struct KeyboardSettings: View {
    @ObservedObject var hotKeys: HotKeys
    @ObservedObject var manager: WindowManager
    @State private var editing: ShortcutAction?
    @State private var error = ""
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("Choose your shortcuts").fontWeight(.semibold)
                Spacer()
                Button("Restore Defaults") { error = hotKeys.save(ShortcutConfiguration()) ?? "" }
            }
            ScrollView {
                VStack(spacing:8) {
                    ForEach(ShortcutAction.allCases) { action in
                        HStack {
                            Text(action.title)
                            Spacer()
                            Button(hotKeys.configuration[action].label) { editing = action }
                                .font(.system(.body,design:.monospaced)).frame(width:140)
                                .accessibilityLabel("Edit \(action.title), \(hotKeys.configuration[action].label)")
                        }
                    }
                }.padding(.trailing,6)
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true) }
            if let action = hotKeys.lastAction {
                Text("Last shortcut: \(action.title)").font(.caption).foregroundStyle(.secondary)
            }
            if manager.shortcutErrors.isEmpty {
                Text("Shortcuts are active across apps. No keyboard recording.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    Text(manager.shortcutErrors.joined(separator:"\n")).font(.caption).foregroundStyle(.orange)
                        .frame(maxWidth:.infinity,alignment:.leading)
                }.frame(maxHeight:65)
            }
        }.padding(18)
        .sheet(item:$editing) { action in
            ShortcutEditor(action:action,initial:hotKeys.configuration[action]) { value in hotKeys.set(action,value) }
        }
    }
}
private struct ShortcutEditor: View {
    let action: ShortcutAction
    let save: (ShortcutBinding) -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var enabled: Bool
    @State private var keyCode: UInt32
    @State private var modifiers: UInt32
    @State private var error = ""
    init(action:ShortcutAction,initial:ShortcutBinding,save:@escaping (ShortcutBinding)->String?) {
        self.action = action; self.save = save
        _enabled = State(initialValue:initial.keyCode != nil)
        _keyCode = State(initialValue:initial.keyCode ?? action.defaultBinding.keyCode!)
        _modifiers = State(initialValue:initial.keyCode == nil ? action.defaultBinding.modifiers : initial.modifiers)
    }
    private var value: ShortcutBinding { enabled ? .init(keyCode:keyCode,modifiers:modifiers) : .disabled }
    private func modifier(_ title:String,_ flag:UInt32) -> some View {
        Toggle(title,isOn:Binding(get:{modifiers & flag != 0},set:{ on in
            if on { modifiers |= flag } else { modifiers &= ~flag }
        })).toggleStyle(.checkbox)
    }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(action.title).font(.title2.bold())
            Toggle("Enable shortcut",isOn:$enabled)
            VStack(alignment:.leading,spacing:14) {
                HStack {
                    modifier("Control ⌃",ShortcutBinding.control)
                    modifier("Option ⌥",ShortcutBinding.option)
                }
                HStack {
                    modifier("Shift ⇧",ShortcutBinding.shift)
                    modifier("Command ⌘",ShortcutBinding.command)
                }
                Picker("Key",selection:$keyCode) {
                    ForEach(ShortcutKey.all) { Text($0.label).tag($0.code) }
                }
                Text("Key names use US keyboard positions. Include Control or Command.")
                    .font(.caption).foregroundStyle(.secondary)
            }.disabled(!enabled)
            Text(value.label).font(.system(.title3,design:.monospaced)).foregroundStyle(.cyan)
            if let validation = value.validationError {
                Text(validation).font(.callout).foregroundStyle(.orange)
            }
            if !error.isEmpty { Text(error).font(.callout).foregroundStyle(.orange).fixedSize(horizontal:false,vertical:true) }
            HStack {
                Button("Use Default") {
                    enabled = true; keyCode = action.defaultBinding.keyCode!; modifiers = action.defaultBinding.modifiers; error = ""
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    if let message = save(value) { error = message } else { dismiss() }
                }.keyboardShortcut(.defaultAction).disabled(value.validationError != nil)
            }
        }.padding(24).frame(width:420)
    }
}
