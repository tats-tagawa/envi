import Foundation

struct RankedNote: Identifiable, Hashable, Sendable {
    var id: URL { note.fileURL }
    var note: Note
    var matchesQuery: Bool
    var score: Int
}

enum FuzzySearch {
    /// Empty query → all notes by updatedAt desc (all match).
    /// Non-empty → matches first (by score), then non-matches (updatedAt desc). All notes stay visible.
    static func rank(_ notes: [Note], query: String) -> [RankedNote] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return notes
                .sorted { $0.updatedAt > $1.updatedAt }
                .map { RankedNote(note: $0, matchesQuery: true, score: 0) }
        }

        var matches: [RankedNote] = []
        var nonMatches: [RankedNote] = []

        for note in notes {
            let titleScore = score(query: trimmed, in: note.title)
            let bodyScore = score(query: trimmed, in: note.body)
            let best = max(titleScore.map { $0 * 2 } ?? -1, bodyScore ?? -1)
            if best >= 0 {
                matches.append(RankedNote(note: note, matchesQuery: true, score: best))
            } else {
                nonMatches.append(RankedNote(note: note, matchesQuery: false, score: -1))
            }
        }

        matches.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.note.updatedAt > rhs.note.updatedAt
        }
        nonMatches.sort { $0.note.updatedAt > $1.note.updatedAt }

        return matches + nonMatches
    }

    /// Indices into `ranked` that are navigable (matches when querying; all when idle).
    static func navigableIndices(in ranked: [RankedNote], query: String) -> [Int] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(ranked.indices)
        }
        return ranked.indices.filter { ranked[$0].matchesQuery }
    }

    /// Higher is better. `nil` means no match.
    static func score(query: String, in text: String) -> Int? {
        let q = Array(query.lowercased())
        let t = Array(text.lowercased())
        guard !q.isEmpty else { return 0 }
        guard !t.isEmpty else { return nil }

        var qi = 0
        var score = 0
        var consecutive = 0
        var lastMatchIndex: Int?

        for (ti, ch) in t.enumerated() {
            guard qi < q.count else { break }
            if ch == q[qi] {
                consecutive += 1
                score += 10 + consecutive * 5
                if ti == 0 { score += 15 }
                if let last = lastMatchIndex, ti == last + 1 {
                    score += 10
                }
                if ti > 0 {
                    let prev = t[ti - 1]
                    if prev == " " || prev == "-" || prev == "_" || prev == "/" {
                        score += 12
                    }
                }
                lastMatchIndex = ti
                qi += 1
            } else {
                consecutive = 0
            }
        }

        guard qi == q.count else { return nil }

        if let last = lastMatchIndex {
            let span = last + 1
            score += max(0, 40 - (span - q.count))
        }

        return score
    }
}
