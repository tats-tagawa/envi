import Foundation

/// Where keyboard focus sits in the main window.
enum EditorFocusTarget: Hashable {
    case search
    case title
    case body
}

extension Notification.Name {
    /// Posted by the Note menu (⌘K). ContentView focuses the search field and selects all text.
    static let focusSearch = Notification.Name("Envi.focusSearch")

    /// Asks the body text view to become first responder and put the caret at the end.
    /// Posted after setting focus to `.body`; the body view handles it asynchronously
    /// so the title field can resign first and the text view is ready.
    static let focusNoteBodyAtEnd = Notification.Name("Envi.focusNoteBodyAtEnd")
}
