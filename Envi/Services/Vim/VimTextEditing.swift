import AppKit
import Foundation

struct VimYankRegister {
    var text = ""
    var linewise = false
}

enum VimTextEditing {
    static func replace(_ textView: NSTextView, range: NSRange, with string: String) {
        guard let storage = textView.textStorage else { return }
        let buffer = VimBuffer(storage.string)
        let clamped = buffer.clampRange(range)
        guard textView.shouldChangeText(in: clamped, replacementString: string) else { return }
        storage.replaceCharacters(in: clamped, with: string)
        textView.didChangeText()
    }

    static func delete(_ textView: NSTextView, range: NSRange) {
        replace(textView, range: range, with: "")
    }

    static func insert(_ textView: NSTextView, string: String, at location: Int) {
        replace(textView, range: NSRange(location: location, length: 0), with: string)
    }

    static func yank(
        from textView: NSTextView,
        range: NSRange,
        linewise: Bool,
        into register: inout VimYankRegister
    ) {
        let buffer = VimBuffer(textView.string)
        let clamped = buffer.clampRange(range)
        let text = buffer.substring(in: clamped)
        register.text = text
        register.linewise = linewise
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func paste(
        _ textView: NSTextView,
        before: Bool,
        register: VimYankRegister,
        cursor: Int
    ) {
        var text = register.text
        if text.isEmpty, let board = NSPasteboard.general.string(forType: .string) {
            text = board
        }
        guard !text.isEmpty else { return }

        let buffer = VimBuffer(textView.string)
        let linewise = register.linewise || text.hasSuffix("\n")

        if linewise {
            let line = buffer.lineRange(containing: cursor)
            let insertAt: Int
            if before {
                insertAt = line.location
            } else {
                insertAt = NSMaxRange(line)
            }
            var payload = text
            if !payload.hasSuffix("\n"), !payload.hasSuffix("\r") {
                payload += "\n"
            }
            insert(textView, string: payload, at: insertAt)
            let newBuffer = VimBuffer(textView.string)
            let dest = newBuffer.firstNonBlank(containing: insertAt)
            applyNormalCursor(textView, at: dest)
        } else {
            let insertAt: Int
            if before {
                insertAt = buffer.clampIndex(cursor)
            } else if buffer.length == 0 {
                insertAt = 0
            } else {
                insertAt = min(cursor + 1, buffer.length)
            }
            insert(textView, string: text, at: insertAt)
            let dest = insertAt + (text as NSString).length - 1
            applyNormalCursor(textView, at: max(insertAt, dest))
        }
    }

    static func openLine(_ textView: NSTextView, above: Bool, cursor: Int) {
        let buffer = VimBuffer(textView.string)
        let line = buffer.lineRange(containing: cursor)
        if above {
            insert(textView, string: "\n", at: line.location)
            applyInsertCursor(textView, at: line.location)
        } else {
            let insertAt = NSMaxRange(line)
            insert(textView, string: "\n", at: insertAt)
            applyInsertCursor(textView, at: insertAt + 1)
        }
    }

    static func applyNormalCursor(_ textView: NSTextView, at cursor: Int) {
        let buffer = VimBuffer(textView.string)
        let sel = buffer.normalSelection(at: cursor)
        textView.setSelectedRange(sel)
        textView.scrollRangeToVisible(sel)
    }

    static func applyInsertCursor(_ textView: NSTextView, at location: Int) {
        let buffer = VimBuffer(textView.string)
        let loc = buffer.clampIndex(location)
        let sel = NSRange(location: loc, length: 0)
        textView.setSelectedRange(sel)
        textView.scrollRangeToVisible(sel)
    }

    /// Normal-mode cursor index from the current selection (block caret = selection start).
    static func normalCursor(from selection: NSRange, buffer: VimBuffer) -> Int {
        buffer.clampCursor(selection.location)
    }
}
