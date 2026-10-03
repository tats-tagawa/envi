import AppKit
import SwiftUI

/// NSTextView that reports when it becomes first responder (keeps SwiftUI focus in sync).
final class FocusAwareTextView: NSTextView {
    var onBecomeFirstResponder: (() -> Void)?

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onBecomeFirstResponder?()
        }
        return became
    }
}

/// Multiline note body. Uses NSTextView so we can place the caret at the end on demand.
struct NoteBodyTextView: NSViewRepresentable {
    /// Identifies which note the text belongs to so we can sync on note switches
    /// even while the text view remains first responder.
    var noteID: URL?
    @Binding var text: String
    var isFocused: Bool
    var onBecameFirstResponder: () -> Void
    var onTextChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let contentSize = scrollView.contentSize
        let textView = FocusAwareTextView(frame: NSRect(origin: .zero, size: contentSize))
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.onBecomeFirstResponder = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onBecameFirstResponder()
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.noteID = noteID

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleFocusAtEnd(_:)),
            name: .focusNoteBodyAtEnd,
            object: nil
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? FocusAwareTextView else { return }
        context.coordinator.parent = self
        textView.onBecomeFirstResponder = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onBecameFirstResponder()
        }

        let noteChanged = context.coordinator.noteID != noteID
        context.coordinator.noteID = noteID

        if textView.string != text {
            // While typing, NSTextView is source of truth. A store-driven re-render can
            // arrive with a stale SwiftUI binding (still "") before @State catches up;
            // applying that would clamp the caret to 0 — noticeable on a brand-new note.
            let isEditing = textView.window?.firstResponder === textView
            if noteChanged || !isEditing {
                let selected = textView.selectedRange()
                textView.string = text
                if noteChanged {
                    // Selection from the previous note is meaningless.
                    let end = (text as NSString).length
                    textView.setSelectedRange(NSRange(location: end, length: 0))
                } else {
                    let max = (text as NSString).length
                    let location = min(selected.location, max)
                    let length = min(selected.length, max - location)
                    textView.setSelectedRange(NSRange(location: location, length: length))
                }
            }
        }

        if isFocused, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteBodyTextView
        var noteID: URL?
        weak var textView: FocusAwareTextView?

        init(_ parent: NoteBodyTextView) {
            self.parent = parent
            self.noteID = parent.noteID
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange(textView.string)
        }

        @objc func handleFocusAtEnd(_ notification: Notification) {
            guard let textView else { return }
            // Async so this runs after the title field has resigned first responder.
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                let length = (textView.string as NSString).length
                textView.setSelectedRange(NSRange(location: length, length: 0))
                textView.scrollRangeToVisible(NSRange(location: length, length: 0))
            }
        }
    }
}
