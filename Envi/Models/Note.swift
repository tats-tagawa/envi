import Foundation

struct Note: Identifiable, Hashable, Sendable {
    var id: URL { fileURL }
    var fileURL: URL
    var title: String
    var body: String
    var tags: [String]
    /// Frontmatter lines other than `tags:`, with a `.tags` slot so a save keeps their order.
    var frontmatter: [NoteMarkdown.FrontmatterEntry] = []
    var createdAt: Date
    var updatedAt: Date

    /// First non-empty body line for list previews; falls back when the note is blank.
    var previewLine: String {
        var index = body.startIndex
        while index < body.endIndex {
            let newline = body[index...].firstIndex(where: \.isNewline) ?? body.endIndex
            let line = body[index..<newline].trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                return String(line)
            }
            if newline == body.endIndex { break }
            index = body.index(after: newline)
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty, trimmedTitle.caseInsensitiveCompare("Untitled") != .orderedSame {
            return trimmedTitle
        }
        return "Untitled"
    }

    /// Created / modified times from the file on disk (not stored in the Markdown).
    static func fileTimestamps(for url: URL) -> (created: Date, updated: Date) {
        let values = try? url.resourceValues(forKeys: [
            .creationDateKey,
            .contentModificationDateKey
        ])
        let now = Date()
        return (
            values?.creationDate ?? now,
            values?.contentModificationDate ?? now
        )
    }
}
