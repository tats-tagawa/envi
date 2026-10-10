import Foundation

/// Plain Markdown on disk, with optional YAML-ish frontmatter for tags:
///
/// ```
/// ---
/// title: Hello
/// tags: work, ideas
/// ---
///
/// Note body…
/// ```
///
/// The opening `---` block is only treated as frontmatter when it contains a `tags:` line.
/// A horizontal rule or other `---` usage at the top of the body is left alone.
/// Keys other than `tags` are kept and written back. A YAML list under `tags:` is read as tags.
enum NoteMarkdown {
    /// One frontmatter line, or the slot where the tags key is rewritten.
    enum FrontmatterEntry: Equatable, Hashable, Sendable {
        case line(String)
        case tags
    }

    struct Parsed: Equatable, Sendable {
        var tags: [String]
        var body: String
        var frontmatter: [FrontmatterEntry]
    }

    static func parse(_ raw: String) -> Parsed {
        var normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        guard normalized.hasPrefix("---\n") || normalized == "---" else {
            return Parsed(tags: [], body: raw, frontmatter: [])
        }

        let afterOpen = normalized.dropFirst(4) // "---\n"
        guard let endRange = afterOpen.range(of: "\n---") else {
            return Parsed(tags: [], body: raw, frontmatter: [])
        }

        let frontmatter = String(afterOpen[..<endRange.lowerBound])
        // Require a tags key so `---` horizontal rules are not eaten as YAML.
        guard frontmatter.split(separator: "\n", omittingEmptySubsequences: false)
            .contains(where: {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .hasPrefix("tags:")
            })
        else {
            return Parsed(tags: [], body: raw, frontmatter: [])
        }

        var body = String(afterOpen[endRange.upperBound...])
        if body.hasPrefix("\n") {
            body.removeFirst()
        }

        let parsed = parseFrontmatter(frontmatter)
        return Parsed(tags: parsed.tags, body: body, frontmatter: parsed.entries)
    }

    static func serialize(
        tags: [String],
        body: String,
        frontmatter: [FrontmatterEntry] = []
    ) -> String {
        let cleaned = normalizeTags(tags)
        let entries = frontmatter.isEmpty ? [FrontmatterEntry.tags] : frontmatter
        let hasOtherLines = entries.contains {
            if case .line = $0 { return true }
            return false
        }
        if cleaned.isEmpty, !hasOtherLines {
            return body
        }

        var lines: [String] = []
        var wroteTags = false
        for entry in entries {
            switch entry {
            case .line(let line):
                lines.append(line)
            case .tags:
                wroteTags = true
                lines.append(tagsLine(cleaned))
            }
        }
        if !wroteTags, !cleaned.isEmpty {
            lines.append(tagsLine(cleaned))
        }
        if lines.isEmpty { return body }
        return "---\n\(lines.joined(separator: "\n"))\n---\n\(body)"
    }

    static func normalizeTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    private static func tagsLine(_ tags: [String]) -> String {
        tags.isEmpty ? "tags:" : "tags: \(tags.joined(separator: ", "))"
    }

    private static func parseFrontmatter(_ frontmatter: String) -> (tags: [String], entries: [FrontmatterEntry]) {
        let lines = frontmatter.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var entries: [FrontmatterEntry] = []
        var tags: [String] = []
        var sawTags = false
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !sawTags, trimmed.lowercased().hasPrefix("tags:") {
                sawTags = true
                entries.append(.tags)
                let value = trimmed.dropFirst("tags:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if value.isEmpty {
                    index += 1
                    while index < lines.count {
                        let item = lines[index].trimmingCharacters(in: .whitespaces)
                        guard item.hasPrefix("-") else { break }
                        let name = stripQuotes(
                            item.dropFirst()
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        if !name.isEmpty {
                            tags.append(name)
                        }
                        index += 1
                    }
                    tags = normalizeTags(tags)
                } else {
                    tags = parseInlineTags(String(value))
                    index += 1
                }
            } else {
                entries.append(.line(line))
                index += 1
            }
        }

        return (tags, entries)
    }

    private static func parseInlineTags(_ value: String) -> [String] {
        let stripped = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return normalizeTags(
            stripped
                .split(separator: ",")
                .map { stripQuotes(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }

    private static func stripQuotes(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let open = value.first
        let close = value.last
        if (open == "\"" && close == "\"") || (open == "'" && close == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
