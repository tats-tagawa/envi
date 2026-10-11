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

    /// Flush debounced note saves (quit / resign active).
    static let flushPendingNotes = Notification.Name("Envi.flushPendingNotes")
}

enum NoteHighlightDelta {
    static let userInfoKey = "delta"

    static func notification(delta: Int) -> Notification {
        Notification(name: .moveNoteHighlight, object: nil, userInfo: [userInfoKey: delta])
    }
}
