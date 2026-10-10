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

    func testPreservesUnknownFrontmatterAndMultilineTags() {
        let raw = """
        ---
        title: Hello
        tags:
          - work
          - ideas
        date: 2020-01-01
        ---
        Body line
        """
        let parsed = NoteMarkdown.parse(raw)
        XCTAssertEqual(parsed.tags, ["work", "ideas"])
        XCTAssertEqual(parsed.body, "Body line")
        let saved = NoteMarkdown.serialize(
            tags: parsed.tags,
            body: parsed.body,
            frontmatter: parsed.frontmatter
        )
        XCTAssertTrue(saved.contains("title: Hello"))
        XCTAssertTrue(saved.contains("date: 2020-01-01"))
        XCTAssertTrue(saved.contains("tags: work, ideas"))
        let again = NoteMarkdown.parse(saved)
        XCTAssertEqual(again.tags, parsed.tags)
        XCTAssertEqual(again.body, parsed.body)
        XCTAssertTrue(again.frontmatter.contains(.line("title: Hello")))
        XCTAssertTrue(again.frontmatter.contains(.line("date: 2020-01-01")))
    }

    func testEmptyTagsKeepOtherFrontmatterKeys() {
        let raw = """
        ---
        title: Hello
        tags: work
        ---
        Body
        """
        let parsed = NoteMarkdown.parse(raw)
        let saved = NoteMarkdown.serialize(tags: [], body: parsed.body, frontmatter: parsed.frontmatter)
        XCTAssertTrue(saved.contains("title: Hello"))
        XCTAssertTrue(saved.contains("tags:"))
        let again = NoteMarkdown.parse(saved)
        XCTAssertEqual(again.tags, [])
        XCTAssertEqual(again.body, "Body")
        XCTAssertTrue(again.frontmatter.contains(.line("title: Hello")))
    }

    func testNormalizeTagsDedupesCaseInsensitively() {
        XCTAssertEqual(
            NoteMarkdown.normalizeTags(["A", "a", "", " B "]),
            ["A", "B"]
        )
    }
}
