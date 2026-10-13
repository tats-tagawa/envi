import AppKit
import SwiftUI

/// Remappable non-Vim app actions.
enum AppShortcutID: String, CaseIterable, Identifiable, Codable {
    case openNotesFolder
    case focusSearch
    case deselectNote
    case renameNote
    case tagNote
    case deleteNote
    case nextNote
    case previousNote
    case toggleTask
    case insertTask
    case setTaskPriority1
    case setTaskPriority2
    case setTaskPriority3
    case clearTaskPriority
    case setTaskDeadline
    case toggleTaskMode
    case searchMoveUp
    case searchMoveDown
    case searchCtrlJ
    case searchCtrlK
    case searchCtrlN
    case searchCtrlP
    case searchActivate
    case searchClear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openNotesFolder: "Open Notes Folder"
        case .focusSearch: "Focus Search"
        case .deselectNote: "Deselect Note"
        case .renameNote: "Rename Note"
        case .tagNote: "Tag Note"
        case .deleteNote: "Delete Note"
        case .nextNote: "Next Note"
        case .previousNote: "Previous Note"
        case .toggleTask: "Toggle Task"
        case .insertTask: "Insert Task"
        case .setTaskPriority1: "Set Task Priority 1"
        case .setTaskPriority2: "Set Task Priority 2"
        case .setTaskPriority3: "Set Task Priority 3"
        case .clearTaskPriority: "Clear Task Priority"
        case .setTaskDeadline: "Set Task Deadline"
        case .toggleTaskMode: "Toggle Task Mode"
        case .searchMoveUp: "Search: Move Up"
        case .searchMoveDown: "Search: Move Down"
        case .searchCtrlJ: "Search: Control J"
        case .searchCtrlK: "Search: Control K"
        case .searchCtrlN: "Search: Control N"
        case .searchCtrlP: "Search: Control P"
        case .searchActivate: "Search: Open / Create"
        case .searchClear: "Search: Clear"
        }
    }

    static var settingsOrdered: [AppShortcutID] {
        [
            .openNotesFolder, .focusSearch, .deselectNote, .renameNote, .tagNote, .deleteNote,
            .nextNote, .previousNote, .toggleTask, .insertTask,
            .setTaskPriority1, .setTaskPriority2, .setTaskPriority3, .clearTaskPriority,
            .setTaskDeadline, .toggleTaskMode,
            .searchMoveUp, .searchMoveDown, .searchCtrlJ, .searchCtrlK, .searchCtrlN, .searchCtrlP,
            .searchActivate, .searchClear,
        ]
    }

    var defaultBinding: AppShortcutBinding {
        switch self {
        case .openNotesFolder: return .mods("o", .command, .shift)
        case .focusSearch: return .mods("l", .command)
        case .deselectNote: return .mods("d", .command)
        case .renameNote: return .mods("r", .command)
        case .tagNote: return .mods("t", .command, .shift)
        case .deleteNote: return .mods("delete", .command)
        case .nextNote: return .mods("j", .command)
        case .previousNote: return .mods("k", .command)
        case .toggleTask: return .mods("return", .command)
        case .insertTask: return .mods("return", .command, .shift)
        case .setTaskPriority1: return .mods("1", .control, .command)
        case .setTaskPriority2: return .mods("2", .control, .command)
        case .setTaskPriority3: return .mods("3", .control, .command)
        case .clearTaskPriority: return .mods("0", .control, .command)
        case .setTaskDeadline: return .mods("d", .command, .shift)
        case .toggleTaskMode: return .mods("t", .control, .command)
        case .searchMoveUp: return .mods("upArrow")
        case .searchMoveDown: return .mods("downArrow")
        case .searchCtrlJ: return .mods("j", .control)
        case .searchCtrlK: return .mods("k", .control)
        case .searchCtrlN: return .mods("n", .control)
        case .searchCtrlP: return .mods("p", .control)
        case .searchActivate: return .mods("return")
        case .searchClear: return .mods("escape")
        }
    }
}

/// Stored chord: character key equivalent + modifier flags.
struct AppShortcutBinding: Codable, Hashable, Sendable {
    /// Letter/digit, or `return`, `escape`, `upArrow`, `downArrow`, `delete`.
    var key: String
    /// Raw value of `NSEvent.ModifierFlags` device-independent mask.
    var modifiers: UInt

    var eventModifiers: EventModifiers {
        var result: EventModifiers = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        return result
    }

    var keyEquivalent: KeyEquivalent {
        switch key {
        case "return": return KeyEquivalent.return
        case "escape": return KeyEquivalent.escape
        case "upArrow": return KeyEquivalent.upArrow
        case "downArrow": return KeyEquivalent.downArrow
        case "delete": return KeyEquivalent.delete
        default:
            if let ch = key.first { return KeyEquivalent(ch) }
            return KeyEquivalent(" ")
        }
    }

    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyDisplay)
        return parts.joined()
    }

    private var keyDisplay: String {
        switch key {
        case "return": "↩"
        case "escape": "Esc"
        case "upArrow": "↑"
        case "downArrow": "↓"
        case "delete": "⌫"
        default: key.uppercased()
        }
    }

    static func mods(_ key: String, _ flags: NSEvent.ModifierFlags...) -> AppShortcutBinding {
        var combined: NSEvent.ModifierFlags = []
        for flag in flags { combined.insert(flag) }
        return AppShortcutBinding(key: key, modifiers: combined.rawValue)
    }

    static func from(event: NSEvent) -> AppShortcutBinding? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key: String
        switch Int(event.keyCode) {
        case 36, 76: key = "return"
        case 53: key = "escape"
        case 126: key = "upArrow"
        case 125: key = "downArrow"
        case 51, 117: key = "delete"
        default:
            guard let chars = event.charactersIgnoringModifiers?.lowercased(),
                  let ch = chars.first,
                  ch.isASCII,
                  !ch.isWhitespace
            else { return nil }
            key = String(ch)
        }
        return AppShortcutBinding(key: key, modifiers: flags.rawValue)
    }

    static func matches(_ binding: AppShortcutBinding, keyPress: KeyPress) -> Bool {
        guard keyPress.modifiers == binding.eventModifiers else { return false }
        switch binding.key {
        case "return": return keyPress.key == .return
        case "escape": return keyPress.key == .escape
        case "upArrow": return keyPress.key == .upArrow
        case "downArrow": return keyPress.key == .downArrow
        case "delete": return keyPress.key == .delete
        default:
            return String(keyPress.characters).lowercased() == binding.key.lowercased()
        }
    }
}
