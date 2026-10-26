import Foundation
import Carbon

public struct ShortcutKey: Identifiable {
    public let code: UInt32
    public let label: String
    public var id: UInt32 { code }
    public static let all: [ShortcutKey] = {
        let keys: [(Int,String)] = [
            (kVK_ANSI_A,"A"),(kVK_ANSI_B,"B"),(kVK_ANSI_C,"C"),(kVK_ANSI_D,"D"),
            (kVK_ANSI_E,"E"),(kVK_ANSI_F,"F"),(kVK_ANSI_G,"G"),(kVK_ANSI_H,"H"),
            (kVK_ANSI_I,"I"),(kVK_ANSI_J,"J"),(kVK_ANSI_K,"K"),(kVK_ANSI_L,"L"),
            (kVK_ANSI_M,"M"),(kVK_ANSI_N,"N"),(kVK_ANSI_O,"O"),(kVK_ANSI_P,"P"),
            (kVK_ANSI_Q,"Q"),(kVK_ANSI_R,"R"),(kVK_ANSI_S,"S"),(kVK_ANSI_T,"T"),
            (kVK_ANSI_U,"U"),(kVK_ANSI_V,"V"),(kVK_ANSI_W,"W"),(kVK_ANSI_X,"X"),
            (kVK_ANSI_Y,"Y"),(kVK_ANSI_Z,"Z"),
            (kVK_ANSI_0,"0"),(kVK_ANSI_1,"1"),(kVK_ANSI_2,"2"),(kVK_ANSI_3,"3"),
            (kVK_ANSI_4,"4"),(kVK_ANSI_5,"5"),(kVK_ANSI_6,"6"),(kVK_ANSI_7,"7"),
            (kVK_ANSI_8,"8"),(kVK_ANSI_9,"9"),
            (kVK_ANSI_Grave,"`"),(kVK_ANSI_Minus,"−"),(kVK_ANSI_Equal,"="),
            (kVK_ANSI_LeftBracket,"["),(kVK_ANSI_RightBracket,"]"),(kVK_ANSI_Backslash,"\\"),
            (kVK_ANSI_Semicolon,";"),(kVK_ANSI_Quote,"'"),(kVK_ANSI_Comma,","),
            (kVK_ANSI_Period,"."),(kVK_ANSI_Slash,"/"),
            (kVK_LeftArrow,"←"),(kVK_RightArrow,"→"),(kVK_UpArrow,"↑"),(kVK_DownArrow,"↓"),
            (kVK_Return,"Return"),(kVK_Space,"Space"),(kVK_Tab,"Tab"),
            (kVK_F1,"F1"),(kVK_F2,"F2"),(kVK_F3,"F3"),(kVK_F4,"F4"),
            (kVK_F5,"F5"),(kVK_F6,"F6"),(kVK_F7,"F7"),(kVK_F8,"F8"),
            (kVK_F9,"F9"),(kVK_F10,"F10"),(kVK_F11,"F11"),(kVK_F12,"F12")]
        return keys.map { ShortcutKey(code: UInt32($0.0), label: $0.1) }
    }()
}
public struct ShortcutBinding: Codable, Equatable, Hashable {
    public var keyCode: UInt32?
    public var modifiers: UInt32
    public init(keyCode: UInt32?, modifiers: UInt32) { self.keyCode = keyCode; self.modifiers = modifiers }
    public static let disabled = ShortcutBinding(keyCode:nil,modifiers:0)
    public static let control = UInt32(controlKey), option = UInt32(optionKey)
    public static let command = UInt32(cmdKey), shift = UInt32(shiftKey)
    public static let allowedModifiers = control | option | command | shift
    public var label: String {
        guard let keyCode else { return "Disabled" }
        let symbols = [(Self.control,"⌃"),(Self.option,"⌥"),(Self.shift,"⇧"),(Self.command,"⌘")]
            .filter { modifiers & $0.0 != 0 }.map { $0.1 }.joined()
        return symbols + " " + (ShortcutKey.all.first { $0.code == keyCode }?.label ?? "Unknown")
    }
    public var validationError: String? {
        guard let keyCode else { return nil }
        guard ShortcutKey.all.contains(where:{$0.code == keyCode}) else { return "Choose a supported key." }
        guard modifiers & ~Self.allowedModifiers == 0 else { return "Unsupported modifier keys." }
        guard modifiers & (Self.control | Self.command) != 0 else { return "Include Control or Command in a global shortcut." }
        return nil
    }
}
public enum ShortcutAction: String, CaseIterable, Codable, Identifiable {
    case capacity1, capacity2, capacity3, capacity4, focus, floatWindow, cycleStack
    case nextWindow, previousWindow, makePrimary, pause, swapLeft, swapRight, swapUp, swapDown
    public var id: String { rawValue }
    public var eventID: UInt32 { UInt32(Self.allCases.firstIndex(of:self)! + 1) }
    public var title: String {
        switch self {
        case .capacity1: return "1 tile"
        case .capacity2: return "2 tiles"
        case .capacity3: return "3 tiles"
        case .capacity4: return "4 tiles"
        case .focus: return "Focus / restore"
        case .floatWindow: return "Float / tile window"
        case .cycleStack: return "Cycle stack"
        case .nextWindow: return "Next window"
        case .previousWindow: return "Previous window"
        case .makePrimary: return "Make primary"
        case .pause: return "Pause / resume"
        case .swapLeft: return "Swap left"
        case .swapRight: return "Swap right"
        case .swapUp: return "Swap up"
        case .swapDown: return "Swap down"
        }
    }
    public var defaultBinding: ShortcutBinding {
        let key: Int
        switch self {
        case .capacity1: key = kVK_ANSI_1
        case .capacity2: key = kVK_ANSI_2
        case .capacity3: key = kVK_ANSI_3
        case .capacity4: key = kVK_ANSI_4
        case .focus: key = kVK_ANSI_Z
        case .floatWindow: key = kVK_ANSI_F
        case .cycleStack: key = kVK_ANSI_Grave
        case .nextWindow: key = kVK_ANSI_RightBracket
        case .previousWindow: key = kVK_ANSI_LeftBracket
        case .makePrimary: key = kVK_Return
        case .pause: key = kVK_ANSI_P
        case .swapLeft: key = kVK_LeftArrow
        case .swapRight: key = kVK_RightArrow
        case .swapUp: key = kVK_UpArrow
        case .swapDown: key = kVK_DownArrow
        }
        let extra = Self.allCases.firstIndex(of:self)! < 4 ? ShortcutBinding.command : 0
        return .init(keyCode:UInt32(key),modifiers:ShortcutBinding.control | ShortcutBinding.option | extra)
    }
}
public struct ShortcutConfiguration: Codable, Equatable {
    public var bindings: [String:ShortcutBinding]
    public init() { bindings = Dictionary(uniqueKeysWithValues:ShortcutAction.allCases.map { ($0.rawValue,$0.defaultBinding) }) }
    public subscript(_ action: ShortcutAction) -> ShortcutBinding {
        get { bindings[action.rawValue] ?? action.defaultBinding }
        set { bindings[action.rawValue] = newValue }
    }
    public var validationError: String? {
        guard Set(bindings.keys) == Set(ShortcutAction.allCases.map(\.rawValue)) else { return "Saved shortcuts are incomplete or unsupported." }
        var seen: [ShortcutBinding:ShortcutAction] = [:]
        for action in ShortcutAction.allCases {
            let value = self[action]
            if let error = value.validationError { return "\(action.title): \(error)" }
            guard value.keyCode != nil else { continue }
            if let other = seen[value] { return "\(value.label) is already assigned to \(other.title)." }
            seen[value] = action
        }
        return nil
    }
}
