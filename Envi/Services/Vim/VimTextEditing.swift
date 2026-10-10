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
            let ns = textView.string as NSString
            let charBefore: unichar = insertAt > line.location ? ns.character(at: insertAt - 1) : 0
            let lineHasBreak = charBefore == 0x0A || charBefore == 0x0D
            insert(textView, string: "\n", at: insertAt)
            // A line that already ended in a newline inserts the blank line at `insertAt`.
            // A line with no break appends the newline, so the caret belongs after it.
            let caret = lineHasBreak ? insertAt : insertAt + 1
            applyInsertCursor(textView, at: caret)
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

    // MARK: - Display-line (soft-wrap) motion

    /// `j`/`k` by visual line fragments. `preferredColumn` stores screen X (points), not buffer column.
    static func displayLineMover(for textView: NSTextView) -> VimVerticalMover {
        VimVerticalMover(
            moveUp: { cursor, count, preferredColumn in
                moveByDisplayLine(textView, from: cursor, steps: -count, preferredScreenX: &preferredColumn)
            },
            moveDown: { cursor, count, preferredColumn in
                moveByDisplayLine(textView, from: cursor, steps: count, preferredScreenX: &preferredColumn)
            }
        )
    }

    static func moveByDisplayLine(
        _ textView: NSTextView,
        from cursor: Int,
        steps: Int,
        preferredScreenX: inout Int?
    ) -> Int {
        let buffer = VimBuffer(textView.string)
        guard buffer.length > 0 else { return 0 }
        guard steps != 0,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            var col = preferredScreenX
            // Without layout, fall back to buffer lines using whatever column we have.
            let dest = steps > 0
                ? buffer.moveDown(cursor, count: abs(steps), preferredColumn: &col)
                : buffer.moveUp(cursor, count: abs(steps), preferredColumn: &col)
            preferredScreenX = col
            return dest
        }

        layoutManager.ensureLayout(for: textContainer)

        var index = buffer.clampCursor(cursor)
        var glyphIndex = layoutManager.glyphIndexForCharacter(at: index)
        glyphIndex = min(glyphIndex, max(layoutManager.numberOfGlyphs - 1, 0))

        var fragmentRange = NSRange(location: 0, length: 0)
        _ = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &fragmentRange)

        if preferredScreenX == nil {
            let locationInFragment = layoutManager.location(forGlyphAt: glyphIndex)
            preferredScreenX = Int(locationInFragment.x.rounded())
        }
        let targetX = CGFloat(preferredScreenX ?? 0)

        let direction = steps > 0 ? 1 : -1
        for _ in 0..<abs(steps) {
            if direction > 0 {
                let nextGlyph = NSMaxRange(fragmentRange)
                guard nextGlyph < layoutManager.numberOfGlyphs else { break }
                glyphIndex = nextGlyph
            } else {
                guard fragmentRange.location > 0 else { break }
                glyphIndex = fragmentRange.location - 1
            }
            let fragmentRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &fragmentRange
            )
            index = characterIndex(
                nearX: targetX,
                in: fragmentRect,
                glyphRange: fragmentRange,
                layoutManager: layoutManager,
                textContainer: textContainer,
                buffer: buffer
            )
        }

        return buffer.clampCursor(index)
    }

    private static func characterIndex(
        nearX targetX: CGFloat,
        in fragmentRect: NSRect,
        glyphRange: NSRange,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer,
        buffer: VimBuffer
    ) -> Int {
        let point = NSPoint(x: fragmentRect.minX + targetX, y: fragmentRect.midY)
        var fraction: CGFloat = 0
        var glyphIndex = layoutManager.glyphIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceThroughGlyph: &fraction
        )
        // Keep the result inside this display line's glyph range.
        if glyphIndex < glyphRange.location {
            glyphIndex = glyphRange.location
        } else if glyphIndex >= NSMaxRange(glyphRange) {
            glyphIndex = max(glyphRange.location, NSMaxRange(glyphRange) - 1)
        }

        var charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let charRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )
        if charRange.length > 0 {
            let end = NSMaxRange(charRange)
            charIndex = min(max(charIndex, charRange.location), end - 1)
            // Prefer landing on content, not the trailing newline of a hard line break.
            if charIndex > charRange.location {
                let c = buffer.text.character(at: charIndex)
                if c == 0x0A || c == 0x0D {
                    charIndex -= 1
                }
            }
        }
        return buffer.clampCursor(charIndex)
    }
}
