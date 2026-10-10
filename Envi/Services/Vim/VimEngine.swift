import Foundation

/// Keys the engine understands (parsed from `NSEvent` by the text view).
enum VimKey: Equatable {
    case escape
    case character(Character)
    case ctrl(Character)
}

/// Vertical motion for Normal/Visual `j`/`k`. Operator-pending `j`/`k` always uses buffer lines.
struct VimVerticalMover {
    let moveUp: (_ cursor: Int, _ count: Int, _ preferredColumn: inout Int?) -> Int
    let moveDown: (_ cursor: Int, _ count: Int, _ preferredColumn: inout Int?) -> Int

    static func bufferLines(_ buffer: VimBuffer) -> VimVerticalMover {
        VimVerticalMover(
            moveUp: { cursor, count, preferredColumn in
                buffer.moveUp(cursor, count: count, preferredColumn: &preferredColumn)
            },
            moveDown: { cursor, count, preferredColumn in
                buffer.moveDown(cursor, count: count, preferredColumn: &preferredColumn)
            }
        )
    }
}

enum VimOperator: Equatable {
    case delete
    case change
    case yank
}

/// Side-effect-free description of what the text view should do.
enum VimAction: Equatable {
    case setMode(VimMode)
    case moveCursor(Int)
    case setSelection(NSRange)
    case delete(NSRange, yank: Bool, linewise: Bool)
    case yank(NSRange, linewise: Bool)
    case replace(NSRange, with: String, yank: Bool, linewise: Bool)
    case openLine(above: Bool)
    case paste(before: Bool)
    case undo
    case redo
    case focusSearch
    case enterInsert(at: Int)
    case beep
}

/// Keystream state machine for Normal / Insert / Visual editing.
struct VimEngine {
    private(set) var mode: VimMode = .insert
    private var countBuffer = 0
    private var pendingOperator: VimOperator?
    private var awaitingSecondG = false
    private var preferredColumn: Int?
    private var visualAnchor: Int?
    /// Active only for the current `handle` call; used by Normal/Visual `j`/`k`.
    private var verticalMover: VimVerticalMover?

    mutating func resetForFocus(insert: Bool) {
        mode = insert ? .insert : .normal
        clearPending()
        preferredColumn = nil
        visualAnchor = nil
    }

    mutating func handle(
        key: VimKey,
        buffer: VimBuffer,
        cursor: Int,
        selection: NSRange,
        verticalMover: VimVerticalMover? = nil
    ) -> [VimAction] {
        self.verticalMover = verticalMover
        defer { self.verticalMover = nil }
        switch mode {
        case .insert:
            return handleInsert(key: key)
        case .normal:
            return handleNormal(key: key, buffer: buffer, cursor: cursor)
        case .visual, .visualLine:
            return handleVisual(key: key, buffer: buffer, cursor: cursor, selection: selection)
        }
    }

    // MARK: - Insert

    private mutating func handleInsert(key: VimKey) -> [VimAction] {
        switch key {
        case .escape:
            mode = .normal
            clearPending()
            return [.setMode(.normal)]
        default:
            // Caller forwards unhandled insert keys to NSTextView.
            return []
        }
    }

    // MARK: - Normal

    private mutating func handleNormal(key: VimKey, buffer: VimBuffer, cursor: Int) -> [VimAction] {
        switch key {
        case .escape:
            if pendingOperator != nil || countBuffer != 0 || awaitingSecondG {
                clearPending()
                return [.beep]
            }
            return [.focusSearch]

        case .ctrl(let c):
            if c == "r" {
                clearPending()
                return [.redo]
            }
            return [.beep]

        case .character(let ch):
            return handleNormalCharacter(ch, buffer: buffer, cursor: cursor)
        }
    }

    private mutating func handleNormalCharacter(
        _ ch: Character,
        buffer: VimBuffer,
        cursor: Int
    ) -> [VimAction] {
        if ch.isNumber, let digit = ch.wholeNumberValue {
            if digit == 0, countBuffer == 0 {
                return finishMotion(to: buffer.lineStart(containing: cursor), buffer: buffer, cursor: cursor)
            }
            countBuffer = min(countBuffer * 10 + digit, 9999)
            return []
        }

        let count = max(countBuffer, 1)

        if awaitingSecondG {
            awaitingSecondG = false
            if ch == "g" {
                // `5gg` goes to line 5; bare `gg` goes to the first line.
                let lineTarget = countBuffer > 0 ? max(countBuffer, 1) : 1
                let dest = indexOfLine(lineTarget, in: buffer)
                if let op = pendingOperator {
                    clearPending()
                    preferredColumn = nil
                    let range = buffer.linewiseRange(from: cursor, to: dest)
                    return applyOperator(op, range: range, linewise: true, buffer: buffer)
                }
                return finishMotion(to: dest, buffer: buffer, cursor: cursor)
            }
            clearPending()
            return [.beep]
        }

        // Operators waiting for a motion / doubled operator.
        if let op = pendingOperator {
            return handleOperatorMotion(op, ch: ch, count: count, buffer: buffer, cursor: cursor)
        }

        switch ch {
        case "i":
            clearPending()
            mode = .insert
            return [.enterInsert(at: cursor), .setMode(.insert)]

        case "a":
            clearPending()
            mode = .insert
            let at = buffer.length == 0 ? 0 : min(cursor + 1, buffer.length)
            return [.enterInsert(at: at), .setMode(.insert)]

        case "I":
            clearPending()
            mode = .insert
            let at = buffer.firstNonBlank(containing: cursor)
            return [.enterInsert(at: at), .setMode(.insert)]

        case "A":
            clearPending()
            mode = .insert
            // Insert before the line's trailing newline (end of line contents).
            let insertAt: Int
            if buffer.length == 0 {
                insertAt = 0
            } else {
                let line = buffer.lineRange(containing: cursor)
                var newlineStart = NSMaxRange(line)
                while newlineStart > line.location {
                    let c = buffer.text.character(at: newlineStart - 1)
                    if c == 0x0A || c == 0x0D { newlineStart -= 1 } else { break }
                }
                insertAt = newlineStart
            }
            return [.enterInsert(at: insertAt), .setMode(.insert)]

        case "o":
            clearPending()
            mode = .insert
            return [.openLine(above: false), .setMode(.insert)]

        case "O":
            clearPending()
            mode = .insert
            return [.openLine(above: true), .setMode(.insert)]

        case "v":
            clearPending()
            mode = .visual
            visualAnchor = cursor
            preferredColumn = nil
            let sel = buffer.normalSelection(at: cursor)
            return [.setMode(.visual), .setSelection(sel)]

        case "V":
            clearPending()
            mode = .visualLine
            visualAnchor = cursor
            preferredColumn = nil
            let sel = buffer.linewiseRange(from: cursor, to: cursor)
            return [.setMode(.visualLine), .setSelection(sel)]

        case "u":
            clearPending()
            return [.undo]

        case "x":
            clearPending()
            preferredColumn = nil
            let range = deleteCharRange(from: cursor, count: count, buffer: buffer, backward: false)
            return range.length > 0 ? [.delete(range, yank: true, linewise: false)] : [.beep]

        case "X":
            clearPending()
            preferredColumn = nil
            let range = deleteCharRange(from: cursor, count: count, buffer: buffer, backward: true)
            return range.length > 0 ? [.delete(range, yank: true, linewise: false)] : [.beep]

        case "p":
            clearPending()
            preferredColumn = nil
            return [.paste(before: false)]

        case "P":
            clearPending()
            preferredColumn = nil
            return [.paste(before: true)]

        case "d":
            // Keep countBuffer so `2dd` / `2dw` work (digits before the operator).
            pendingOperator = .delete
            return []

        case "c":
            pendingOperator = .change
            return []

        case "y":
            pendingOperator = .yank
            return []

        case "D":
            clearPending()
            preferredColumn = nil
            let start = cursor
            let end = buffer.lineEnd(containing: cursor)
            let range = buffer.characterwiseRange(from: start, to: end, inclusive: true)
            // Don't delete the newline; D is to end of line.
            return range.length > 0 ? [.delete(range, yank: true, linewise: false)] : []

        case "C":
            clearPending()
            preferredColumn = nil
            mode = .insert
            let start = cursor
            let end = buffer.lineEnd(containing: cursor)
            let range = buffer.characterwiseRange(from: start, to: end, inclusive: true)
            if range.length > 0 {
                return [.replace(range, with: "", yank: true, linewise: false), .enterInsert(at: range.location), .setMode(.insert)]
            }
            return [.enterInsert(at: cursor), .setMode(.insert)]

        case "h":
            return finishMotion(
                to: buffer.moveLeft(cursor, count: count),
                buffer: buffer,
                cursor: cursor,
                resetColumn: true
            )

        case "l":
            return finishMotion(
                to: buffer.moveRight(cursor, count: count),
                buffer: buffer,
                cursor: cursor,
                resetColumn: true
            )

        case "j":
            return finishMotion(
                to: moveVertically(down: true, cursor: cursor, count: count, buffer: buffer),
                buffer: buffer,
                cursor: cursor,
                resetColumn: false
            )

        case "k":
            return finishMotion(
                to: moveVertically(down: false, cursor: cursor, count: count, buffer: buffer),
                buffer: buffer,
                cursor: cursor,
                resetColumn: false
            )

        case "w":
            return finishMotion(
                to: buffer.wordForward(cursor, count: count),
                buffer: buffer,
                cursor: cursor,
                resetColumn: true
            )

        case "b":
            return finishMotion(
                to: buffer.wordBackward(cursor, count: count),
                buffer: buffer,
                cursor: cursor,
                resetColumn: true
            )

        case "e":
            return finishMotion(
                to: buffer.wordEnd(cursor, count: count),
                buffer: buffer,
                cursor: cursor,
                resetColumn: true
            )

        case "^":
            return finishMotion(
                to: buffer.firstNonBlank(containing: cursor),
                buffer: buffer,
                cursor: cursor,
                resetColumn: true
            )

        case "$":
            // With count, go to end of count-1 lines down.
            var dest = buffer.lineEnd(containing: cursor)
            if count > 1 {
                var col: Int? = Int.max / 4
                dest = buffer.moveDown(cursor, count: count - 1, preferredColumn: &col)
                dest = buffer.lineEnd(containing: dest)
            }
            return finishMotion(to: dest, buffer: buffer, cursor: cursor, resetColumn: true)

        case "g":
            // Keep countBuffer so `5gg` can jump to line 5.
            awaitingSecondG = true
            return []

        case "G":
            if countBuffer > 0 {
                let dest = indexOfLine(count, in: buffer)
                return finishMotion(to: dest, buffer: buffer, cursor: cursor, resetColumn: true)
            }
            return finishMotion(to: buffer.bufferEnd(), buffer: buffer, cursor: cursor, resetColumn: true)

        default:
            clearPending()
            return [.beep]
        }
    }

    private mutating func handleOperatorMotion(
        _ op: VimOperator,
        ch: Character,
        count: Int,
        buffer: VimBuffer,
        cursor: Int
    ) -> [VimAction] {
        // Doubled operators: dd / cc / yy
        if (op == .delete && ch == "d") || (op == .change && ch == "c") || (op == .yank && ch == "y") {
            clearPending()
            preferredColumn = nil
            var endCursor = cursor
            if count > 1 {
                var col: Int? = 0
                endCursor = buffer.moveDown(cursor, count: count - 1, preferredColumn: &col)
            }
            let range = buffer.linewiseRange(from: cursor, to: endCursor)
            return applyOperator(op, range: range, linewise: true, buffer: buffer)
        }

        // Motions after operator
        let motionDest: Int?
        var inclusive = false
        var linewise = false

        switch ch {
        case "h":
            motionDest = buffer.moveLeft(cursor, count: count)
        case "l":
            motionDest = buffer.moveRight(cursor, count: count)
            inclusive = true
        case "j":
            var col: Int? = preferredColumn ?? buffer.column(of: cursor)
            let dest = buffer.moveDown(cursor, count: count, preferredColumn: &col)
            preferredColumn = col
            motionDest = dest
            linewise = true
        case "k":
            var col: Int? = preferredColumn ?? buffer.column(of: cursor)
            let dest = buffer.moveUp(cursor, count: count, preferredColumn: &col)
            preferredColumn = col
            motionDest = dest
            linewise = true
        case "w":
            motionDest = buffer.wordForward(cursor, count: count)
        case "b":
            motionDest = buffer.wordBackward(cursor, count: count)
        case "e":
            motionDest = buffer.wordEnd(cursor, count: count)
            inclusive = true
        case "0":
            motionDest = buffer.lineStart(containing: cursor)
        case "^":
            motionDest = buffer.firstNonBlank(containing: cursor)
        case "$":
            motionDest = buffer.lineEnd(containing: cursor)
            inclusive = true
        case "g":
            awaitingSecondG = true
            return []
        case "G":
            if countBuffer > 0 {
                motionDest = indexOfLine(count, in: buffer)
            } else {
                motionDest = buffer.bufferEnd()
            }
            linewise = true
        default:
            clearPending()
            return [.beep]
        }

        guard let dest = motionDest else {
            clearPending()
            return [.beep]
        }

        clearPending()
        preferredColumn = nil

        let range: NSRange
        if linewise {
            range = buffer.linewiseRange(from: cursor, to: dest)
        } else if dest >= cursor {
            range = buffer.characterwiseRange(from: cursor, to: dest, inclusive: inclusive)
        } else {
            // Backward motion: from dest to cursor (exclusive of cursor for h/b like Vim).
            range = NSRange(location: dest, length: cursor - dest)
        }

        return applyOperator(op, range: range, linewise: linewise, buffer: buffer)
    }

    private mutating func applyOperator(
        _ op: VimOperator,
        range: NSRange,
        linewise: Bool,
        buffer: VimBuffer
    ) -> [VimAction] {
        let clamped = buffer.clampRange(range)
        guard clamped.length > 0 || op == .change else { return [.beep] }

        switch op {
        case .delete:
            return [.delete(clamped, yank: true, linewise: linewise)]
        case .yank:
            return [.yank(clamped, linewise: linewise)]
        case .change:
            mode = .insert
            return [
                .replace(clamped, with: "", yank: true, linewise: linewise),
                .enterInsert(at: clamped.location),
                .setMode(.insert),
            ]
        }
    }

    private mutating func finishMotion(
        to dest: Int,
        buffer: VimBuffer,
        cursor: Int,
        resetColumn: Bool = true
    ) -> [VimAction] {
        if let op = pendingOperator {
            // Operator + motion that came through finishMotion (e.g. after gg).
            let inclusive = false
            let range: NSRange
            if dest >= cursor {
                range = buffer.characterwiseRange(from: cursor, to: dest, inclusive: inclusive)
            } else {
                range = NSRange(location: dest, length: cursor - dest)
            }
            clearPending()
            preferredColumn = nil
            return applyOperator(op, range: range, linewise: false, buffer: buffer)
        }

        clearPending()
        if resetColumn {
            preferredColumn = nil
        }
        let clamped = buffer.clampCursor(dest)
        return [.moveCursor(clamped)]
    }

    // MARK: - Visual

    private mutating func handleVisual(
        key: VimKey,
        buffer: VimBuffer,
        cursor: Int,
        selection: NSRange
    ) -> [VimAction] {
        let anchor = visualAnchor ?? selection.location

        switch key {
        case .escape:
            mode = .normal
            visualAnchor = nil
            clearPending()
            preferredColumn = nil
            return [.setMode(.normal), .moveCursor(buffer.clampCursor(cursor))]

        case .ctrl:
            return [.beep]

        case .character(let ch):
            if awaitingSecondG {
                awaitingSecondG = false
                if ch == "g" {
                    let lineTarget = countBuffer > 0 ? max(countBuffer, 1) : 1
                    return updateVisualSelection(
                        to: indexOfLine(lineTarget, in: buffer),
                        anchor: anchor,
                        buffer: buffer,
                        resetColumn: true
                    )
                }
                return [.beep]
            }

            if ch.isNumber, let digit = ch.wholeNumberValue {
                if digit == 0, countBuffer == 0 {
                    return updateVisualSelection(to: buffer.lineStart(containing: cursor), anchor: anchor, buffer: buffer)
                }
                countBuffer = min(countBuffer * 10 + digit, 9999)
                return []
            }

            let explicitCount = countBuffer
            let count = max(countBuffer, 1)
            countBuffer = 0

            switch ch {
            case "h":
                return updateVisualSelection(
                    to: buffer.moveLeft(cursor, count: count),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "l":
                return updateVisualSelection(
                    to: buffer.moveRight(cursor, count: count),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "j":
                let dest = moveVertically(down: true, cursor: cursor, count: count, buffer: buffer)
                return updateVisualSelection(to: dest, anchor: anchor, buffer: buffer, resetColumn: false)
            case "k":
                let dest = moveVertically(down: false, cursor: cursor, count: count, buffer: buffer)
                return updateVisualSelection(to: dest, anchor: anchor, buffer: buffer, resetColumn: false)
            case "w":
                return updateVisualSelection(
                    to: buffer.wordForward(cursor, count: count),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "b":
                return updateVisualSelection(
                    to: buffer.wordBackward(cursor, count: count),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "e":
                return updateVisualSelection(
                    to: buffer.wordEnd(cursor, count: count),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "0":
                return updateVisualSelection(
                    to: buffer.lineStart(containing: cursor),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "^":
                return updateVisualSelection(
                    to: buffer.firstNonBlank(containing: cursor),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "$":
                return updateVisualSelection(
                    to: buffer.lineEnd(containing: cursor),
                    anchor: anchor,
                    buffer: buffer,
                    resetColumn: true
                )
            case "g":
                awaitingSecondG = true
                return []
            case "G":
                let dest = explicitCount > 0 ? indexOfLine(count, in: buffer) : buffer.bufferEnd()
                return updateVisualSelection(to: dest, anchor: anchor, buffer: buffer, resetColumn: true)

            case "d", "x":
                let range = currentVisualRange(anchor: anchor, cursor: cursor, buffer: buffer)
                let linewise = mode == .visualLine
                mode = .normal
                visualAnchor = nil
                clearPending()
                return [.delete(range, yank: true, linewise: linewise), .setMode(.normal)]

            case "c", "s":
                let range = currentVisualRange(anchor: anchor, cursor: cursor, buffer: buffer)
                let linewise = mode == .visualLine
                mode = .insert
                visualAnchor = nil
                clearPending()
                return [
                    .replace(range, with: "", yank: true, linewise: linewise),
                    .enterInsert(at: range.location),
                    .setMode(.insert),
                ]

            case "y":
                let range = currentVisualRange(anchor: anchor, cursor: cursor, buffer: buffer)
                let linewise = mode == .visualLine
                mode = .normal
                visualAnchor = nil
                clearPending()
                return [.yank(range, linewise: linewise), .setMode(.normal), .moveCursor(buffer.clampCursor(anchor))]

            case "v":
                if mode == .visual {
                    mode = .normal
                    visualAnchor = nil
                    return [.setMode(.normal), .moveCursor(buffer.clampCursor(cursor))]
                }
                mode = .visual
                return updateVisualSelection(to: cursor, anchor: anchor, buffer: buffer)

            case "V":
                if mode == .visualLine {
                    mode = .normal
                    visualAnchor = nil
                    return [.setMode(.normal), .moveCursor(buffer.clampCursor(cursor))]
                }
                mode = .visualLine
                return updateVisualSelection(to: cursor, anchor: anchor, buffer: buffer)

            default:
                return [.beep]
            }
        }
    }

    private mutating func updateVisualSelection(
        to dest: Int,
        anchor: Int,
        buffer: VimBuffer,
        resetColumn: Bool = true
    ) -> [VimAction] {
        if resetColumn {
            preferredColumn = nil
        }
        let cursor = buffer.clampCursor(dest)
        let range = currentVisualRange(anchor: anchor, cursor: cursor, buffer: buffer)
        return [.moveCursor(cursor), .setSelection(range)]
    }

    private func currentVisualRange(anchor: Int, cursor: Int, buffer: VimBuffer) -> NSRange {
        if mode == .visualLine {
            return buffer.linewiseRange(from: anchor, to: cursor)
        }
        let a = buffer.clampCursor(anchor)
        let b = buffer.clampCursor(cursor)
        let start = min(a, b)
        let end = max(a, b)
        return NSRange(location: start, length: end - start + (buffer.length > 0 ? 1 : 0))
    }

    // MARK: - Helpers

    /// Normal/Visual vertical motion. Uses `verticalMover` when provided (display lines);
    /// otherwise buffer (newline) lines. Updates `preferredColumn`.
    private mutating func moveVertically(
        down: Bool,
        cursor: Int,
        count: Int,
        buffer: VimBuffer
    ) -> Int {
        var col = preferredColumn
        let mover = verticalMover ?? .bufferLines(buffer)
        let dest = down
            ? mover.moveDown(cursor, count, &col)
            : mover.moveUp(cursor, count, &col)
        preferredColumn = col
        return dest
    }

    private mutating func clearPending() {
        countBuffer = 0
        pendingOperator = nil
        awaitingSecondG = false
    }

    private func deleteCharRange(
        from cursor: Int,
        count: Int,
        buffer: VimBuffer,
        backward: Bool
    ) -> NSRange {
        guard buffer.length > 0 else { return NSRange(location: 0, length: 0) }
        if backward {
            let start = max(0, cursor - count)
            return NSRange(location: start, length: cursor - start)
        }
        let end = min(buffer.length, cursor + count)
        return NSRange(location: cursor, length: end - cursor)
    }

    private func indexOfLine(_ oneBased: Int, in buffer: VimBuffer) -> Int {
        guard buffer.length > 0 else { return 0 }
        var line = 1
        var i = 0
        let target = max(oneBased, 1)
        while i < buffer.length {
            if line == target {
                return buffer.firstNonBlank(containing: i)
            }
            let range = buffer.lineRange(containing: i)
            let next = NSMaxRange(range)
            if next >= buffer.length {
                return buffer.firstNonBlank(containing: buffer.bufferEnd())
            }
            i = next
            line += 1
        }
        return buffer.bufferEnd()
    }
}

extension VimEngine {
    /// Whether insert-mode keys should be forwarded to the text view.
    var shouldForwardInsertKeys: Bool {
        mode == .insert
    }
}
