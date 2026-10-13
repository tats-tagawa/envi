import Foundation

/// A GFM task-list line extracted from a note body.
struct TaskItem: Identifiable, Hashable, Sendable {
    /// Stable enough for list identity within a given body snapshot.
    var id: String { "\(noteURL.absoluteString)#\(lineIndex)" }

    var noteURL: URL
    var noteTitle: String
    var noteUpdatedAt: Date
    var lineIndex: Int
    var text: String
    var isDone: Bool
    /// 1 = highest … 3 = lowest.
    var priority: Int? = nil
    var deadline: Date? = nil
}

struct RankedTask: Identifiable, Hashable, Sendable {
    var id: String { task.id }
    var task: TaskItem
    var matchesQuery: Bool
    var score: Int
}
