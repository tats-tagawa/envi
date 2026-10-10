import XCTest
@testable import Envi

final class FuzzySearchTests: XCTestCase {
    func testExactTitleOutranksBody() {
        let notes = [
            Note(
                fileURL: URL(fileURLWithPath: "/tmp/other.md"),
                title: "other",
                body: "testing appears in body",
                tags: [],
                createdAt: .now,
                updatedAt: .now
            ),
            Note(
                fileURL: URL(fileURLWithPath: "/tmp/test.md"),
                title: "test",
                body: "",
                tags: [],
                createdAt: .now,
                updatedAt: .now.addingTimeInterval(-100)
            ),
        ]
        let ranked = FuzzySearch.rank(notes, query: "test")
        XCTAssertEqual(ranked.first?.note.title, "test")
        XCTAssertTrue(ranked[0].score > ranked[1].score)
    }

    func testScoreNilWhenNoMatch() {
        XCTAssertNil(FuzzySearch.score(query: "xyz", in: "hello"))
    }

    func testLongBodyMatchStaysAMatch() throws {
        let body = String(repeating: "word ", count: 80) + "meeting" + String(repeating: " word", count: 80)
        XCTAssertGreaterThan(body.count, 200)
        let score = try XCTUnwrap(FuzzySearch.score(query: "meeting", in: body))
        XCTAssertGreaterThanOrEqual(score, 0)

        let notes = [
            Note(
                fileURL: URL(fileURLWithPath: "/tmp/long.md"),
                title: "notes",
                body: body,
                tags: [],
                createdAt: .now,
                updatedAt: .now
            )
        ]
        let ranked = FuzzySearch.rank(notes, query: "meeting")
        XCTAssertTrue(ranked[0].matchesQuery)
        XCTAssertEqual(FuzzySearch.navigableIndices(in: ranked, query: "meeting"), [0])
    }

    func testScorePrefersTighterMatch() {
        let tight = FuzzySearch.score(query: "test", in: "test")!
        let loose = FuzzySearch.score(query: "test", in: "testing")!
        XCTAssertGreaterThan(tight, loose)
    }

    func testEmptyQueryMarksAllNavigable() {
        let notes = [
            Note(
                fileURL: URL(fileURLWithPath: "/tmp/a.md"),
                title: "a",
                body: "",
                tags: [],
                createdAt: .now,
                updatedAt: .now
            )
        ]
        let ranked = FuzzySearch.rank(notes, query: "")
        XCTAssertEqual(FuzzySearch.navigableIndices(in: ranked, query: "").count, 1)
    }
}
