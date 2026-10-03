import Foundation

/// UTF-16-indexed buffer helpers for Vim motions (matches `NSRange` / `NSTextView`).
struct VimBuffer {
    let text: NSString

    var length: Int { text.length }

    init(_ string: String) {
        text = string as NSString
    }

    init(_ text: NSString) {
        self.text = text
    }

    // MARK: - Lines

    func lineRange(containing index: Int) -> NSRange {
        let clamped = clampIndex(index)
        return text.lineRange(for: NSRange(location: clamped, length: 0))
    }

    func lineStart(containing index: Int) -> Int {
        lineRange(containing: index).location
    }

    /// First non-blank character on the line (`^`), or line start if the line is blank.
    func firstNonBlank(containing index: Int) -> Int {
        let range = lineRange(containing: index)
        var i = range.location
        let end = NSMaxRange(range)
        while i < end {
            let c = text.character(at: i)
            if c == 0x0A || c == 0x0D { break }
            if !isBlank(c) { return i }
            i += 1
        }
        return range.location
    }

    /// Last character on the line excluding the newline (`$`). Empty line → line start.
    func lineEnd(containing index: Int) -> Int {
        let range = lineRange(containing: index)
        var end = NSMaxRange(range)
        while end > range.location {
            let c = text.character(at: end - 1)
            if c == 0x0A || c == 0x0D {
                end -= 1
            } else {
                break
            }
        }
        if end > range.location {
            return end - 1
        }
        return range.location
    }

    func column(of index: Int) -> Int {
        index - lineStart(containing: index)
    }

    // MARK: - Character motion

    func moveLeft(_ cursor: Int, count: Int = 1) -> Int {
        max(0, cursor - max(count, 1))
    }

    func moveRight(_ cursor: Int, count: Int = 1) -> Int {
        guard length > 0 else { return 0 }
        let maxCursor = length - 1
        return min(maxCursor, cursor + max(count, 1))
    }

    func moveUp(_ cursor: Int, count: Int = 1, preferredColumn: inout Int?) -> Int {
        let steps = max(count, 1)
        var index = clampCursor(cursor)
        if preferredColumn == nil {
            preferredColumn = column(of: index)
        }
        for _ in 0..<steps {
            let start = lineStart(containing: index)
            if start == 0 { break }
            let prevLineEnd = start - 1
            index = indexOnLine(containing: prevLineEnd, column: preferredColumn ?? 0)
        }
        return index
    }

    func moveDown(_ cursor: Int, count: Int = 1, preferredColumn: inout Int?) -> Int {
        let steps = max(count, 1)
        var index = clampCursor(cursor)
        if preferredColumn == nil {
            preferredColumn = column(of: index)
        }
        for _ in 0..<steps {
            let range = lineRange(containing: index)
            let next = NSMaxRange(range)
            if next >= length { break }
            index = indexOnLine(containing: next, column: preferredColumn ?? 0)
        }
        return index
    }

    // MARK: - Word motion

    func wordForward(_ cursor: Int, count: Int = 1) -> Int {
        var index = clampIndex(cursor)
        for _ in 0..<max(count, 1) {
            index = nextWordStart(from: index)
        }
        return clampCursor(index)
    }

    func wordBackward(_ cursor: Int, count: Int = 1) -> Int {
        var index = clampIndex(cursor)
        for _ in 0..<max(count, 1) {
            index = previousWordStart(from: index)
        }
        return clampCursor(index)
    }

    func wordEnd(_ cursor: Int, count: Int = 1) -> Int {
        var index = clampIndex(cursor)
        for _ in 0..<max(count, 1) {
            index = nextWordEnd(from: index)
        }
        return clampCursor(index)
    }

    // MARK: - Buffer extremes

    func bufferStart() -> Int { 0 }

    func bufferEnd() -> Int {
        guard length > 0 else { return 0 }
        return length - 1
    }

    // MARK: - Ranges

    /// Characterwise range from cursor through motion end (inclusive for operators like `dw`/`de` as needed).
    func characterwiseRange(from start: Int, to end: Int, inclusive: Bool) -> NSRange {
        let a = clampIndex(start)
        var b = clampIndex(end)
        if inclusive, length > 0 {
            b = min(length, b + 1)
        }
        if a <= b {
            return NSRange(location: a, length: b - a)
        }
        return NSRange(location: b, length: a - b)
    }

    /// Linewise range covering every line from `start` through `end` (includes trailing newlines).
    func linewiseRange(from start: Int, to end: Int) -> NSRange {
        let a = lineRange(containing: start)
        let b = lineRange(containing: end)
        let loc = min(a.location, b.location)
        let maxEnd = max(NSMaxRange(a), NSMaxRange(b))
        return NSRange(location: loc, length: maxEnd - loc)
    }

    func substring(in range: NSRange) -> String {
        let clamped = clampRange(range)
        guard clamped.length > 0 else { return "" }
        return text.substring(with: clamped)
    }

    // MARK: - Helpers

    func clampIndex(_ index: Int) -> Int {
        min(max(index, 0), length)
    }

    /// Cursor index valid for Normal-mode block cursor (on a character, or 0 if empty).
    func clampCursor(_ index: Int) -> Int {
        guard length > 0 else { return 0 }
        return min(max(index, 0), length - 1)
    }

    func clampRange(_ range: NSRange) -> NSRange {
        let loc = min(max(range.location, 0), length)
        let len = min(max(range.length, 0), length - loc)
        return NSRange(location: loc, length: len)
    }

    func normalSelection(at cursor: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let c = clampCursor(cursor)
        return NSRange(location: c, length: 1)
    }

    private func indexOnLine(containing index: Int, column: Int) -> Int {
        let start = lineStart(containing: index)
        let end = lineEnd(containing: index)
        if end < start { return start }
        return min(start + column, end)
    }

    private func nextWordStart(from index: Int) -> Int {
        guard length > 0 else { return 0 }
        var i = clampIndex(index)
        if i >= length { return clampCursor(length - 1) }

        let kind = charKind(at: i)
        // Leave current word / punctuation run.
        if kind != .blank {
            while i < length, charKind(at: i) == kind {
                i += 1
            }
        }
        // Skip blanks.
        while i < length, charKind(at: i) == .blank {
            i += 1
        }
        if i >= length {
            return clampCursor(length - 1)
        }
        return i
    }

    private func previousWordStart(from index: Int) -> Int {
        guard length > 0 else { return 0 }
        var i = clampIndex(index)
        if i == 0 { return 0 }

        // Step back off current position.
        i = max(0, i - 1)
        while i > 0, charKind(at: i) == .blank {
            i -= 1
        }
        let kind = charKind(at: i)
        while i > 0, charKind(at: i - 1) == kind {
            i -= 1
        }
        return i
    }

    private func nextWordEnd(from index: Int) -> Int {
        guard length > 0 else { return 0 }
        var i = clampIndex(index)

        // If not at end of a word, move into / across blanks first.
        if i < length - 1 {
            let atEndOfWord = charKind(at: i) != .blank
                && (i + 1 >= length || charKind(at: i + 1) != charKind(at: i))
            if atEndOfWord {
                i += 1
            }
        }

        while i < length, charKind(at: i) == .blank {
            i += 1
        }
        if i >= length {
            return clampCursor(length - 1)
        }

        let kind = charKind(at: i)
        while i + 1 < length, charKind(at: i + 1) == kind {
            i += 1
        }
        return i
    }

    private enum CharKind {
        case blank
        case word
        case punct
    }

    private func charKind(at index: Int) -> CharKind {
        guard index >= 0, index < length else { return .blank }
        let c = text.character(at: index)
        if isBlank(c) { return .blank }
        if isWordChar(c) { return .word }
        return .punct
    }

    private func isBlank(_ c: unichar) -> Bool {
        c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D
    }

    private func isWordChar(_ c: unichar) -> Bool {
        let scalars = String(UnicodeScalar(c)!).unicodeScalars
        guard let s = scalars.first else { return false }
        return CharacterSet.alphanumerics.contains(s) || s == "_"
    }
}
