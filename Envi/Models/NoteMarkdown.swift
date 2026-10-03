import Foundation

/// Plain Markdown on disk, with optional YAML-ish frontmatter for tags:
///
/// ```
/// ---
/// tags: work, ideas
/// ---
///
/// Note body…
/// ```
enum NoteMarkdown {
    static func parse(_ raw: String) -> (tags: [String], body: String) {
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalized.hasPrefix("---\n") || normalized == "---" else {
            return ([], raw)
        }

        let afterOpen = normalized.dropFirst(4) // "---\n"
        guard let endRange = afterOpen.range(of: "\n---") else {
            return ([], raw)
        }

        let frontmatter = String(afterOpen[..<endRange.lowerBound])
        var body = String(afterOpen[endRange.upperBound...])
        if body.hasPrefix("\n") {
            body.removeFirst()
        }

        return (parseTags(from: frontmatter), body)
    }

    static func serialize(tags: [String], body: String) -> String {
        let cleaned = normalizeTags(tags)
        guard !cleaned.isEmpty else { return body }
        return "---\ntags: \(cleaned.joined(separator: ", "))\n---\n\(body)"
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

    private static func parseTags(from frontmatter: String) -> [String] {
        for line in frontmatter.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("tags:") else { continue }
            let value = trimmed.dropFirst("tags:".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            // Support `tags: a, b` and `tags: [a, b]`.
            let stripped = value
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            return normalizeTags(
                stripped
                    .split(separator: ",")
                    .map { String($0) }
            )
        }
        return []
    }
}
