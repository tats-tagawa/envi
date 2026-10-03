import Foundation

struct Note: Identifiable, Hashable, Sendable {
    var id: URL { fileURL }
    var fileURL: URL
    var title: String
    var body: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    /// First non-empty body line for list previews; falls back when the note is blank.
    var previewLine: String {
        if let line = body.split(whereSeparator: \.isNewline)
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return line
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
