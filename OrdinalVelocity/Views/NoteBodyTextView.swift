import AppKit
import SwiftUI

enum EditorFocusTarget: Hashable {
    case search
    case title
    case body
}

extension Notification.Name {
    static let focusNoteBodyAtEnd = Notification.Name("OrdinalVelocity.focusNoteBodyAtEnd")
}

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

/// Multiline note body backed by NSTextView so we can place the caret at the end on demand.
struct NoteBodyTextView: NSViewRepresentable {
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
        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        textView.onBecomeFirstResponder = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onBecameFirstResponder()
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView

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

        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let max = (text as NSString).length
            let location = min(selected.location, max)
            let length = min(selected.length, max - location)
            textView.setSelectedRange(NSRange(location: location, length: length))
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
        weak var textView: FocusAwareTextView?

        init(_ parent: NoteBodyTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onTextChange(textView.string)
        }

        @objc func handleFocusAtEnd(_ notification: Notification) {
            guard let textView else { return }
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                let length = (textView.string as NSString).length
                textView.setSelectedRange(NSRange(location: length, length: 0))
                textView.scrollRangeToVisible(NSRange(location: length, length: 0))
            }
        }
    }
}
