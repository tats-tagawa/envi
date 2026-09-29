import Foundation

struct Note: Identifiable, Hashable, Sendable {
    var id: URL { fileURL }
    var fileURL: URL
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

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
