import Foundation

enum FuzzySearch {
    /// Returns notes ranked by fuzzy score (best first). Empty query → sorted by updatedAt desc.
    static func filter(_ notes: [Note], query: String) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return notes.sorted { $0.updatedAt > $1.updatedAt }
        }

        let scored: [(Note, Int)] = notes.compactMap { note in
            let titleScore = score(query: trimmed, in: note.title)
            let bodyScore = score(query: trimmed, in: note.body)
            let best = max(titleScore.map { $0 * 2 } ?? -1, bodyScore ?? -1)
            guard best >= 0 else { return nil }
            return (note, best)
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.updatedAt > rhs.0.updatedAt
            }
            .map(\.0)
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

        // Prefer tighter matches (fewer gaps relative to query length).
        if let last = lastMatchIndex {
            let span = last + 1
            score += max(0, 40 - (span - q.count))
        }

        return score
    }
}
