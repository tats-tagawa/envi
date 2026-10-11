import AppKit
import SwiftUI

/// NSTextView that reports first-responder changes and optionally runs Vim modal editing.
final class FocusAwareTextView: NSTextView {
    var onBecomeFirstResponder: (() -> Void)?
    var vimEnabled = false {
        didSet {
            guard vimEnabled != oldValue else { return }
            if vimEnabled {
                // Newly enabled while focused: start in Insert so typing still works.
                if window?.firstResponder === self {
                    enterInsertAtCaret()
                }
            } else {
                // The block caret is a real selection. Leave a caret so the next key inserts.
                let loc = selectedRange().location
                setSelectedRange(NSRange(location: loc, length: 0))
            }
        }
    }
    /// When true, Normal/Visual j/k use soft-wrapped display lines (see Settings).
    var vimJKMovesByDisplayLines = true
    var onVimModeChange: ((VimMode) -> Void)?

    private var vimEngine = VimEngine()
    private var yankRegister = VimYankRegister()
    /// Tracks cursor for visual mode after moveCursor + setSelection action pairs.
    private var vimCursorOverride: Int?

    private var vimVerticalMover: VimVerticalMover? {
        vimJKMovesByDisplayLines ? VimTextEditing.displayLineMover(for: self) : nil
    }

    /// Open-from-search / note switch: land in Insert at end.
    func prepareVimInsertAtEnd() {
        guard vimEnabled else { return }
        vimEngine.resetForFocus(insert: true)
        onVimModeChange?(vimEngine.mode)
        let length = (string as NSString).length
        setSelectedRange(NSRange(location: length, length: 0))
        scrollRangeToVisible(selectedRange())
    }

    private func enterInsertAtCaret() {
        vimEngine.resetForFocus(insert: true)
        onVimModeChange?(vimEngine.mode)
        let loc = selectedRange().location
        setSelectedRange(NSRange(location: loc, length: 0))
    }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became {
            onBecomeFirstResponder?()
            // Do not reset mode here — SwiftUI often re-asserts first responder, which
            // would clobber Normal mode back to Insert and make modal editing feel broken.
            if vimEnabled {
                onVimModeChange?(vimEngine.mode)
            }
        }
        return became
    }

    override func keyDown(with event: NSEvent) {
        guard vimEnabled else {
            super.keyDown(with: event)
            return
        }

        // Leave Cmd shortcuts (undo, copy, paste, etc.) to AppKit.
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            super.keyDown(with: event)
            return
        }

        guard let key = Self.vimKey(from: event) else {
            if vimEngine.shouldForwardInsertKeys {
                super.keyDown(with: event)
            } else {
                NSSound.beep()
            }
            return
        }

        // Insert mode: Esc handled by engine; everything else → NSTextView.
        if vimEngine.shouldForwardInsertKeys, key != .escape {
            super.keyDown(with: event)
            return
        }

        let buffer = VimBuffer(string)
        let selection = selectedRange()
        let preservedOverride = vimCursorOverride
        let cursor = vimCursorOverride
            ?? VimTextEditing.normalCursor(from: selection, buffer: buffer)
        vimCursorOverride = nil

        let actions = vimEngine.handle(
            key: key,
            buffer: buffer,
            cursor: cursor,
            selection: selection,
            verticalMover: vimVerticalMover
        )

        if actions.isEmpty {
            // Digits and the first `g` do not move. Keep the visual cursor for the next key.
            vimCursorOverride = preservedOverride
            if vimEngine.shouldForwardInsertKeys {
                super.keyDown(with: event)
            }
            return
        }

        applyVimActions(actions)
    }

    /// Also catch Escape delivered as cancelOperation (some focus paths skip raw Esc).
    override func doCommand(by selector: Selector) {
        if vimEnabled, selector == #selector(NSResponder.cancelOperation(_:)) {
            let buffer = VimBuffer(string)
            let selection = selectedRange()
            let cursor = vimCursorOverride
                ?? VimTextEditing.normalCursor(from: selection, buffer: buffer)
            vimCursorOverride = nil
            let actions = vimEngine.handle(
                key: .escape,
                buffer: buffer,
                cursor: cursor,
                selection: selection,
                verticalMover: vimVerticalMover
            )
            if !actions.isEmpty {
                applyVimActions(actions)
                return
            }
        }

        if vimEnabled, !vimEngine.shouldForwardInsertKeys {
            // Swallow AppKit movement/delete commands in Normal/Visual.
            return
        }
        super.doCommand(by: selector)
    }

    private func applyVimActions(_ actions: [VimAction]) {
        for action in actions {
            switch action {
            case .setMode(let mode):
                onVimModeChange?(mode)
                if mode == .normal {
                    let buffer = VimBuffer(string)
                    let cursor = VimTextEditing.normalCursor(from: selectedRange(), buffer: buffer)
                    VimTextEditing.applyNormalCursor(self, at: cursor)
                }

            case .moveCursor(let index):
                vimCursorOverride = index
                if vimEngine.mode.isVisual {
                    break
                }
                VimTextEditing.applyNormalCursor(self, at: index)

            case .setSelection(let range):
                setSelectedRange(range)
                scrollRangeToVisible(range)

            case .delete(let range, let yank, let linewise):
                if yank {
                    VimTextEditing.yank(from: self, range: range, linewise: linewise, into: &yankRegister)
                }
                let cursorAfter = range.location
                VimTextEditing.delete(self, range: range)
                if vimEngine.mode == .normal {
                    VimTextEditing.applyNormalCursor(self, at: cursorAfter)
                }

            case .yank(let range, let linewise):
                VimTextEditing.yank(from: self, range: range, linewise: linewise, into: &yankRegister)

            case .replace(let range, let string, let yank, let linewise):
                if yank {
                    VimTextEditing.yank(from: self, range: range, linewise: linewise, into: &yankRegister)
                }
                VimTextEditing.replace(self, range: range, with: string)

            case .openLine(let above):
                let buffer = VimBuffer(string)
                let cursor = VimTextEditing.normalCursor(from: selectedRange(), buffer: buffer)
                VimTextEditing.openLine(self, above: above, cursor: cursor)

            case .paste(let before):
                let buffer = VimBuffer(string)
                let cursor = VimTextEditing.normalCursor(from: selectedRange(), buffer: buffer)
                VimTextEditing.paste(self, before: before, register: yankRegister, cursor: cursor)

            case .undo:
                undoManager?.undo()
                if vimEngine.mode == .normal {
                    let buffer = VimBuffer(string)
                    let cursor = VimTextEditing.normalCursor(from: selectedRange(), buffer: buffer)
                    VimTextEditing.applyNormalCursor(self, at: cursor)
                }

            case .redo:
                undoManager?.redo()
                if vimEngine.mode == .normal {
                    let buffer = VimBuffer(string)
                    let cursor = VimTextEditing.normalCursor(from: selectedRange(), buffer: buffer)
                    VimTextEditing.applyNormalCursor(self, at: cursor)
                }

            case .focusSearch:
                NotificationCenter.default.post(name: .focusSearch, object: nil)

            case .enterInsert(let location):
                VimTextEditing.applyInsertCursor(self, at: location)

            case .beep:
                NSSound.beep()
            }
        }
    }

    private static func vimKey(from event: NSEvent) -> VimKey? {
        if event.keyCode == 53 { // Escape
            return .escape
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.control) {
            let chars = (event.charactersIgnoringModifiers ?? "").lowercased()
            if let c = chars.first, c.isLetter {
                return .ctrl(c)
            }
            return nil
        }

        // Allow Shift (for A/I/O/$/^) and Caps Lock; reject Option.
        if flags.contains(.option) {
            return nil
        }

        // Use `characters` so Shift is applied ($ ^ A I …). Ignore modifiers alone.
        guard let chars = event.characters, !chars.isEmpty else { return nil }
        // Skip private-use / control characters from arrows, etc. (those go via doCommand).
        guard chars.unicodeScalars.allSatisfy({ $0.value >= 32 || $0 == "\t" }) else {
            return nil
        }
        guard let ch = chars.first, chars.count == 1 else { return nil }
        return .character(ch)
    }
}

/// Multiline note body. Uses NSTextView so we can place the caret at the end on demand.
struct NoteBodyTextView: NSViewRepresentable {
    /// Identifies which note the text belongs to so we can sync on note switches
    /// even while the text view remains first responder.
    var noteID: URL?
    @Binding var text: String
    var isFocused: Bool
    var vimEnabled: Bool
    /// When this equals `noteID`, a URL change is a rename: keep the caret and Vim mode.
    var preserveCaretForURL: URL?
    var onConsumedCaretPreserve: () -> Void = {}
    @Binding var vimMode: VimMode
    @AppStorage("vimJKMovesByDisplayLines") private var vimJKMovesByDisplayLines = true
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
        textView.textContainerInset = NSSize(width: 2, height: 4)
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
        textView.vimEnabled = vimEnabled
        textView.vimJKMovesByDisplayLines = vimJKMovesByDisplayLines
        textView.onBecomeFirstResponder = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onBecameFirstResponder()
        }
        textView.onVimModeChange = { [weak coordinator = context.coordinator] mode in
            // Update synchronously so the status bar tracks Esc → Normal immediately.
            coordinator?.parent.vimMode = mode
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
        textView.vimEnabled = vimEnabled
        textView.vimJKMovesByDisplayLines = vimJKMovesByDisplayLines
        textView.onBecomeFirstResponder = { [weak coordinator = context.coordinator] in
            coordinator?.parent.onBecameFirstResponder()
        }
        textView.onVimModeChange = { [weak coordinator = context.coordinator] mode in
            coordinator?.parent.vimMode = mode
        }

        let noteChanged = context.coordinator.noteID != noteID
        let keepCaret = noteChanged && noteID != nil && noteID == preserveCaretForURL
        context.coordinator.noteID = noteID
        if keepCaret {
            let carriedURL = noteID
            DispatchQueue.main.async {
                if preserveCaretForURL == carriedURL {
                    onConsumedCaretPreserve()
                }
            }
        }

        if textView.string != text {
            // While typing, NSTextView is source of truth. A store-driven re-render can
            // arrive with a stale SwiftUI binding (still "") before @State catches up;
            // applying that would clamp the caret to 0 — noticeable on a brand-new note.
            let isEditing = textView.window?.firstResponder === textView
            if noteChanged || !isEditing {
                let selected = textView.selectedRange()
                textView.string = text
                if noteChanged, !keepCaret {
                    // Selection from the previous note is meaningless.
                    let end = (text as NSString).length
                    textView.setSelectedRange(NSRange(location: end, length: 0))
                    if vimEnabled {
                        textView.prepareVimInsertAtEnd()
                    }
                } else {
                    let max = (text as NSString).length
                    let location = min(selected.location, max)
                    let length = min(selected.length, max - location)
                    textView.setSelectedRange(NSRange(location: location, length: length))
                }
            }
        } else if noteChanged, vimEnabled, !keepCaret {
            textView.prepareVimInsertAtEnd()
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
                if textView.vimEnabled {
                    textView.prepareVimInsertAtEnd()
                } else {
                    let length = (textView.string as NSString).length
                    textView.setSelectedRange(NSRange(location: length, length: 0))
                    textView.scrollRangeToVisible(NSRange(location: length, length: 0))
                }
            }
        }
    }
}
