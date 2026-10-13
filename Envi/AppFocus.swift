import Foundation

/// Where keyboard focus sits in the main window.
enum EditorFocusTarget: Hashable {
    case search
    case body
}

extension Notification.Name {
    /// Focus the search field (⌘L).
    static let focusSearch = Notification.Name("Envi.focusSearch")

    /// ⌘D — deselect the current note and restore the previous search text.
    static let deselectRestoreSearch = Notification.Name("Envi.deselectRestoreSearch")

    /// ⌘R — rename the selected note inline in the results list.
    static let renameSelectedNote = Notification.Name("Envi.renameSelectedNote")

    /// ⌘⇧T — edit tags inline in the results list.
    static let editTags = Notification.Name("Envi.editTags")

    /// ⌫ / Delete — move the selected note to the Trash.
    static let deleteSelectedNote = Notification.Name("Envi.deleteSelectedNote")

    /// ⌘J / ⌘K — move highlight in the notes list.
    static let moveNoteHighlight = Notification.Name("Envi.moveNoteHighlight")

    /// Asks the body text view to become first responder and put the caret at the end.
    static let focusNoteBodyAtEnd = Notification.Name("Envi.focusNoteBodyAtEnd")

    /// ⌃⌘T — sticky Task mode (list tasks / create task notes).
    static let toggleTaskMode = Notification.Name("Envi.toggleTaskMode")

    /// ⌘Return — toggle the GFM checkbox on the current body line.
    static let toggleTaskAtCursor = Notification.Name("Envi.toggleTaskAtCursor")

    /// ⌘⇧Return — insert `- [ ] ` at/near the caret in the body.
    static let insertTaskAtCursor = Notification.Name("Envi.insertTaskAtCursor")

    /// ⌃⌘1/2/3/0 — set or clear priority on the current task line (`userInfo["priority"]`).
    static let setTaskPriorityAtCursor = Notification.Name("Envi.setTaskPriorityAtCursor")

    /// ⌘⇧D — ask the main window to present the deadline sheet.
    static let requestTaskDeadlineSheet = Notification.Name("Envi.requestTaskDeadlineSheet")

    /// Apply deadline from the sheet (`userInfo["deadline"]` as Date, or `clear` to remove).
    static let applyTaskDeadlineAtCursor = Notification.Name("Envi.applyTaskDeadlineAtCursor")

    /// Flush debounced note saves (quit / resign active).
    static let flushPendingNotes = Notification.Name("Envi.flushPendingNotes")
}

enum TaskPriorityUserInfo {
    static let key = "priority"
}

enum TaskDeadlineUserInfo {
    static let key = "deadline"
    static let clearKey = "clear"
}

enum NoteHighlightDelta {
    static let userInfoKey = "delta"

    static func notification(delta: Int) -> Notification {
        Notification(name: .moveNoteHighlight, object: nil, userInfo: [userInfoKey: delta])
    }
}
