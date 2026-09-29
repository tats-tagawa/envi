import Foundation

struct Note: Identifiable, Hashable, Sendable {
    var id: URL { fileURL }
    var fileURL: URL
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    static func dates(for url: URL) -> (created: Date, updated: Date) {
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
