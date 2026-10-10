import Foundation

struct RankedNote: Identifiable, Hashable, Sendable {
    var id: URL { note.fileURL }
    var note: Note
    var matchesQuery: Bool
    var score: Int

    var tagsDisplay: String {
        note.tags.joined(separator: ", ")
    }
}

enum FuzzySearch {
    /// Empty query → all notes by updatedAt desc.
    /// Non-empty → matches first (by score), then non-matches (updatedAt desc).
    /// All notes stay visible; non-matches are dimmed in the UI.
    static func rank(_ notes: [Note], query: String) -> [RankedNote] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // Idle list: treat every note as a match so ↑↓ can reach all of them.
            return notes
                .sorted { $0.updatedAt > $1.updatedAt }
                .map { RankedNote(note: $0, matchesQuery: true, score: 0) }
        }

        var matches: [RankedNote] = []
        var nonMatches: [RankedNote] = []

        for note in notes {
            let best = bestScore(query: trimmed, note: note)
            if best >= 0 {
                matches.append(RankedNote(note: note, matchesQuery: true, score: best))
            } else {
                nonMatches.append(RankedNote(note: note, matchesQuery: false, score: -1))
            }
        }

        matches.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            // Prefer shorter titles when scores tie ("test" before "testing").
            if lhs.note.title.count != rhs.note.title.count {
                return lhs.note.title.count < rhs.note.title.count
            }
            return lhs.note.updatedAt > rhs.note.updatedAt
        }
        nonMatches.sort { $0.note.updatedAt > $1.note.updatedAt }

        return matches + nonMatches
    }

    /// Title / tags / preview first; only scan the full body when needed.
    private static func bestScore(query: String, note: Note) -> Int {
        let titleScore = score(query: query, in: note.title).map {
            titleBoost(query: query, title: note.title, base: $0)
        }
        // Strong title hits already outrank body — skip the expensive body scan.
        if let titleScore, titleScore >= 15_000 {
            return titleScore
        }

        let previewScore = score(query: query, in: note.previewLine).map { $0 * 2 }
        let tagScore = note.tags.compactMap { score(query: query, in: $0) }.max().map { $0 * 2 }

        let lightBest = [titleScore, previewScore, tagScore].compactMap { $0 }.max()
        if let lightBest, lightBest >= 0 {
            // Still check body only when it could beat a weak title/preview/tag hit.
            if lightBest >= 200 {
                return lightBest
            }
            if let bodyScore = score(query: query, in: note.body) {
                return max(lightBest, bodyScore)
            }
            return lightBest
        }

        return score(query: query, in: note.body) ?? -1
    }

    /// Rows the user can move between with ↑↓.
    /// While searching, only matches; with an empty query, every row.
    static func navigableIndices(in ranked: [RankedNote], query: String) -> [Int] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(ranked.indices)
        }
        return ranked.indices.filter { ranked[$0].matchesQuery }
    }

    /// Fuzzy subsequence score. Higher is better; `nil` means no match.
    ///
    /// Scoring ideas (kept simple on purpose):
    /// - base points per matched character, plus a streak bonus for consecutive hits
    /// - bonus for matching at the start of the string or after a word separator
    /// - small bonus when matched characters sit close together
    static func score(query: String, in text: String) -> Int? {
        let q = Array(query.lowercased())
        let t = Array(text.lowercased())
        guard !q.isEmpty else { return 0 }
        guard !t.isEmpty else { return nil }

        // Fast reject: every query character must appear at least once.
        var available = Dictionary(t.map { ($0, 1) }, uniquingKeysWith: +)
        for ch in q {
            guard let n = available[ch], n > 0 else { return nil }
            available[ch] = n - 1
        }

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
                    if prev == " " || prev == "-" || prev == "_" || prev == "/" || prev == "#" {
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
            // Prefer tighter covers of shorter strings (query "test" → "test" > "testing").
            // Clamp so a real match in a long note cannot fall below "matched".
            // Length is only a tie-break; rank already prefers shorter titles.
            score -= max(0, t.count - q.count) * 3
        }

        return max(score, 0)
    }

    /// Extra weight so an exact or prefix title match beats longer fuzzy title hits.
    private static func titleBoost(query: String, title: String, base: Int) -> Int {
        let q = query.lowercased()
        let t = title.lowercased()
        if t == q { return base + 50_000 }
        if t.hasPrefix(q) { return base + 25_000 }
        if t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { String($0) == q }) {
            return base + 15_000
        }
        return base * 2
    }
}
