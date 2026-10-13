import Foundation

/// Parsed GFM task-list line (`- [ ]` / `- [x]`) with optional trailing metadata tokens.
struct ParsedTaskLine: Equatable, Sendable {
    var indent: String
    var bullet: String
    var isDone: Bool
    /// Task title with `!N` / `@YYYY-MM-DD` tokens stripped.
    var text: String
    var priority: Int?
    var deadline: Date?
}

/// Parse and rewrite GitHub-flavored markdown task list lines.
enum TaskMarkdown {
    /// Optional indent, `-` or `*`, optional space, `[ ]` / `[x]` / `[X]`, then payload.
    private static let lineRegex = try! NSRegularExpression(
        pattern: #"^([ \t]*)([-*])[ \t]+\[([ xX])\](?:[ \t]+(.*))?$"#
    )

    private static let priorityRegex = try! NSRegularExpression(pattern: #"^!([123])$"#)
    private static let deadlineRegex = try! NSRegularExpression(pattern: #"^@(\d{4}-\d{2}-\d{2})$"#)

    private static let deadlineFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Extract

    /// All task lines in a note body, in order.
    static func tasks(in note: Note) -> [TaskItem] {
        let lines = note.body.split(separator: "\n", omittingEmptySubsequences: false)
        var items: [TaskItem] = []
        for (index, line) in lines.enumerated() {
            guard let parsed = parseLine(String(line)) else { continue }
            items.append(
                TaskItem(
                    noteURL: note.fileURL,
                    noteTitle: note.title,
                    noteUpdatedAt: note.updatedAt,
                    lineIndex: index,
                    text: parsed.text,
                    isDone: parsed.isDone,
                    priority: parsed.priority,
                    deadline: parsed.deadline
                )
            )
        }
        return items
    }

    /// Returns a parsed task when `line` is a checkbox line.
    static func parseLine(_ line: String) -> ParsedTaskLine? {
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = lineRegex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }
        let indent = ns.substring(with: match.range(at: 1))
        let bullet = ns.substring(with: match.range(at: 2))
        let marker = ns.substring(with: match.range(at: 3))
        let isDone = marker.lowercased() == "x"
        let payload: String
        if match.range(at: 4).location != NSNotFound {
            payload = ns.substring(with: match.range(at: 4))
        } else {
            payload = ""
        }
        let meta = stripMetadata(from: payload)
        return ParsedTaskLine(
            indent: indent,
            bullet: bullet,
            isDone: isDone,
            text: meta.text,
            priority: meta.priority,
            deadline: meta.deadline
        )
    }

    /// Body for a newly created dedicated task note.
    static func openTaskBody(text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = trimmed.isEmpty ? "Untitled" : trimmed
        return serializeLine(
            indent: "",
            bullet: "-",
            isDone: false,
            text: label,
            priority: nil,
            deadline: nil
        ) + "\n"
    }

    static func serializeLine(
        indent: String,
        bullet: String,
        isDone: Bool,
        text: String,
        priority: Int?,
        deadline: Date?
    ) -> String {
        let marker = isDone ? "x" : " "
        var payload = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let priority, (1...3).contains(priority) {
            payload = payload.isEmpty ? "!\(priority)" : "\(payload) !\(priority)"
        }
        if let deadline, let stamp = formatDeadline(deadline) {
            payload = payload.isEmpty ? "@\(stamp)" : "\(payload) @\(stamp)"
        }
        if payload.isEmpty {
            return "\(indent)\(bullet) [\(marker)]"
        }
        return "\(indent)\(bullet) [\(marker)] \(payload)"
    }

    // MARK: - Rewrite

    /// Flip the checkbox on `lineIndex`. Returns `nil` if that line is not a task.
    static func toggleCheckbox(in body: String, lineIndex: Int) -> String? {
        mutateLine(in: body, lineIndex: lineIndex) { line in
            guard var parsed = parseLine(line) else { return nil }
            parsed.isDone.toggle()
            return serialize(parsed)
        }
    }

    static func setPriority(in body: String, lineIndex: Int, priority: Int?) -> String? {
        mutateLine(in: body, lineIndex: lineIndex) { line in
            guard var parsed = parseLine(line) else { return nil }
            if let priority {
                guard (1...3).contains(priority) else { return nil }
                parsed.priority = priority
            } else {
                parsed.priority = nil
            }
            return serialize(parsed)
        }
    }

    static func setDeadline(in body: String, lineIndex: Int, deadline: Date?) -> String? {
        mutateLine(in: body, lineIndex: lineIndex) { line in
            guard var parsed = parseLine(line) else { return nil }
            if let deadline {
                parsed.deadline = startOfDay(deadline)
            } else {
                parsed.deadline = nil
            }
            return serialize(parsed)
        }
    }

    /// Insert an open task at/near the caret. Returns new body and UTF-16 caret after `- [ ] `.
    static func insertOpenTask(
        in body: String,
        utf16Offset: Int,
        above: Bool = false
    ) -> (body: String, caretUTF16: Int) {
        var lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let lineIndex = lineIndex(forUTF16Offset: utf16Offset, in: body)
        let safeIndex = lines.isEmpty ? 0 : min(max(lineIndex, 0), lines.count - 1)

        let indent: String
        if lines.isEmpty {
            indent = ""
        } else {
            let current = lines[safeIndex]
            indent = listIndent(of: current)
            if current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let taskLine = serializeLine(
                    indent: indent,
                    bullet: "-",
                    isDone: false,
                    text: "",
                    priority: nil,
                    deadline: nil
                ) + " "
                lines[safeIndex] = taskLine
                let caret = utf16OffsetOfLine(safeIndex, in: lines) + (taskLine as NSString).length
                return (lines.joined(separator: "\n"), caret)
            }
        }

        let taskLine = serializeLine(
            indent: indent,
            bullet: "-",
            isDone: false,
            text: "",
            priority: nil,
            deadline: nil
        ) + " "
        let insertAt: Int
        if lines.isEmpty {
            lines = [taskLine]
            insertAt = 0
        } else if above {
            insertAt = safeIndex
            lines.insert(taskLine, at: insertAt)
        } else {
            insertAt = safeIndex + 1
            lines.insert(taskLine, at: insertAt)
        }
        let caret = utf16OffsetOfLine(insertAt, in: lines) + (taskLine as NSString).length
        return (lines.joined(separator: "\n"), caret)
    }

    /// Flip `- [ ]` ↔ `- [x]` on a single line. Preserves indent, bullet, text, and metadata.
    static func toggleCheckboxLine(_ line: String) -> String? {
        guard var parsed = parseLine(line) else { return nil }
        parsed.isDone.toggle()
        return serialize(parsed)
    }

    /// Zero-based line index for a UTF-16 caret offset in `body`.
    static func lineIndex(forUTF16Offset offset: Int, in body: String) -> Int {
        let ns = body as NSString
        let clamped = max(0, min(offset, ns.length))
        var line = 0
        var i = 0
        while i < clamped {
            if ns.character(at: i) == 10 /* \n */ {
                line += 1
            }
            i += 1
        }
        return line
    }

    static func formatDeadline(_ date: Date) -> String? {
        deadlineFormatter.string(from: startOfDay(date))
    }

    static func parseDeadline(_ string: String) -> Date? {
        guard let date = deadlineFormatter.date(from: string) else { return nil }
        return startOfDay(date)
    }

    // MARK: - Private

    private static func serialize(_ parsed: ParsedTaskLine) -> String {
        serializeLine(
            indent: parsed.indent,
            bullet: parsed.bullet,
            isDone: parsed.isDone,
            text: parsed.text,
            priority: parsed.priority,
            deadline: parsed.deadline
        )
    }

    private static func mutateLine(
        in body: String,
        lineIndex: Int,
        transform: (String) -> String?
    ) -> String? {
        var lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.indices.contains(lineIndex) else { return nil }
        guard let replacement = transform(lines[lineIndex]) else { return nil }
        lines[lineIndex] = replacement
        return lines.joined(separator: "\n")
    }

    private static func stripMetadata(from payload: String) -> (text: String, priority: Int?, deadline: Date?) {
        var tokens = payload.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var priority: Int?
        var deadline: Date?

        while let last = tokens.last {
            let ns = last as NSString
            let range = NSRange(location: 0, length: ns.length)
            if let match = priorityRegex.firstMatch(in: last, options: [], range: range),
               let value = Int(ns.substring(with: match.range(at: 1))) {
                priority = value
                tokens.removeLast()
                continue
            }
            if let match = deadlineRegex.firstMatch(in: last, options: [], range: range) {
                let stamp = ns.substring(with: match.range(at: 1))
                if let date = parseDeadline(stamp) {
                    deadline = date
                    tokens.removeLast()
                    continue
                }
            }
            break
        }

        return (tokens.joined(separator: " "), priority, deadline)
    }

    private static func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func listIndent(of line: String) -> String {
        var indent = ""
        for ch in line {
            if ch == " " || ch == "\t" {
                indent.append(ch)
            } else {
                break
            }
        }
        return indent
    }

    private static func utf16OffsetOfLine(_ lineIndex: Int, in lines: [String]) -> Int {
        var offset = 0
        for i in 0..<lineIndex {
            offset += (lines[i] as NSString).length
            offset += 1 // newline between lines
        }
        return offset
    }
}
