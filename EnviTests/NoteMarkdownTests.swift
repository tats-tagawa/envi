import XCTest
@testable import Envi

final class NoteMarkdownTests: XCTestCase {
    func testParseTagsFrontmatter() {
        let raw = """
        ---
        tags: work, ideas
        ---
        Hello
        """
        let parsed = NoteMarkdown.parse(raw)
        XCTAssertEqual(parsed.tags, ["work", "ideas"])
        XCTAssertEqual(parsed.body, "Hello")
    }

    func testParseBracketTags() {
        let raw = """
        ---
        tags: [alpha, beta]
        ---
        Body
        """
        let parsed = NoteMarkdown.parse(raw)
        XCTAssertEqual(parsed.tags, ["alpha", "beta"])
        XCTAssertEqual(parsed.body, "Body")
    }

    func testHorizontalRuleIsNotFrontmatter() {
        let raw = """
        ---
        not tags
        ---
        Still body
        """
        let parsed = NoteMarkdown.parse(raw)
        XCTAssertEqual(parsed.tags, [])
        XCTAssertEqual(parsed.body, raw)
    }

    func testSerializeRoundTrip() {
        let body = "Note body"
        let raw = NoteMarkdown.serialize(tags: ["Work", "work", " ideas "], body: body)
        let parsed = NoteMarkdown.parse(raw)
        XCTAssertEqual(parsed.tags, ["Work", "ideas"])
        XCTAssertEqual(parsed.body, body)
    }

    func testNormalizeTagsDedupesCaseInsensitively() {
        XCTAssertEqual(
            NoteMarkdown.normalizeTags(["A", "a", "", " B "]),
            ["A", "B"]
        )
    }
}
