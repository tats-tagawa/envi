import XCTest
@testable import Envi

final class VimEngineTests: XCTestCase {
    private func buffer(_ text: String) -> VimBuffer { VimBuffer(text) }

    private func run(
        _ keys: [VimKey],
        text: String,
        cursor: Int = 0
    ) -> (engine: VimEngine, actions: [VimAction]) {
        var engine = VimEngine()
        engine.resetForFocus(insert: false)
        let buf = buffer(text)
        var last: [VimAction] = []
        var cursorPos = cursor
        for key in keys {
            last = engine.handle(
                key: key,
                buffer: buf,
                cursor: cursorPos,
                selection: NSRange(location: cursorPos, length: buf.length > 0 ? 1 : 0)
            )
            for action in last {
                if case .moveCursor(let idx) = action {
                    cursorPos = idx
                }
            }
        }
        return (engine, last)
    }

    func testCountBeforeOperatorDeletesMultipleLines() {
        let text = "one\ntwo\nthree\n"
        let (_, actions) = run(
            [.character("2"), .character("d"), .character("d")],
            text: text
        )
        guard case .delete(let range, yank: true, linewise: true) = actions.first else {
            return XCTFail("Expected linewise delete, got \(actions)")
        }
        // Two lines from the start: "one\ntwo\n"
        XCTAssertEqual(range, NSRange(location: 0, length: 8))
    }

    func testCountBeforeOperatorWithWordMotion() {
        let text = "alpha beta gamma"
        let (_, actions) = run(
            [.character("2"), .character("d"), .character("w")],
            text: text
        )
        guard case .delete(let range, yank: true, linewise: false) = actions.first else {
            return XCTFail("Expected characterwise delete, got \(actions)")
        }
        XCTAssertEqual((text as NSString).substring(with: range), "alpha beta ")
    }

    func testCountBeforeGGGoesToLine() {
        let text = "a\nb\nc\nd\n"
        let (_, actions) = run(
            [.character("3"), .character("g"), .character("g")],
            text: text
        )
        guard case .moveCursor(let index) = actions.first else {
            return XCTFail("Expected moveCursor, got \(actions)")
        }
        // Line 3 is "c"
        XCTAssertEqual(index, (text as NSString).range(of: "c").location)
    }

    func testDigitsAfterOperatorStillWork() {
        let text = "alpha beta gamma"
        let (_, actions) = run(
            [.character("d"), .character("2"), .character("w")],
            text: text
        )
        guard case .delete(let range, yank: true, linewise: false) = actions.first else {
            return XCTFail("Expected characterwise delete, got \(actions)")
        }
        XCTAssertEqual((text as NSString).substring(with: range), "alpha beta ")
    }
}
