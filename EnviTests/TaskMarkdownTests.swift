import XCTest
@testable import Envi

final class TaskMarkdownTests: XCTestCase {
    func testParseOpenAndDoneLines() {
        let open = TaskMarkdown.parseLine("- [ ] Buy milk")
        XCTAssertEqual(open?.isDone, false)
        XCTAssertEqual(open?.text, "Buy milk")
        XCTAssertNil(open?.priority)
        XCTAssertNil(open?.deadline)

        let done = TaskMarkdown.parseLine("- [x] Ship PR")
        XCTAssertEqual(done?.isDone, true)
        XCTAssertEqual(done?.text, "Ship PR")

        let starred = TaskMarkdown.parseLine("  * [X] Nested")
        XCTAssertEqual(starred?.isDone, true)
        XCTAssertEqual(starred?.text, "Nested")
        XCTAssertEqual(starred?.indent, "  ")
    }

    func testParseRejectsNonTaskLines() {
        XCTAssertNil(TaskMarkdown.parseLine("- not a task"))
        XCTAssertNil(TaskMarkdown.parseLine("plain text"))
        XCTAssertNil(TaskMarkdown.parseLine("[ ] almost"))
    }

    func testParsePriorityAndDeadlineTokens() {
        let parsed = TaskMarkdown.parseLine("- [ ] Buy milk !1 @2026-10-20")
        XCTAssertEqual(parsed?.text, "Buy milk")
        XCTAssertEqual(parsed?.priority, 1)
        XCTAssertEqual(
            TaskMarkdown.formatDeadline(parsed!.deadline!),
            "2026-10-20"
        )

        let reversed = TaskMarkdown.parseLine("- [x] Ship !2 @2026-01-02")
        // Tokens stripped from the end in either order as long as they trail.
        XCTAssertEqual(reversed?.text, "Ship")
        XCTAssertEqual(reversed?.priority, 2)

        let deadlineOnly = TaskMarkdown.parseLine("- [ ] Call @2026-12-01")
        XCTAssertEqual(deadlineOnly?.text, "Call")
        XCTAssertNil(deadlineOnly?.priority)
        XCTAssertEqual(TaskMarkdown.formatDeadline(deadlineOnly!.deadline!), "2026-12-01")
    }

    func testSerializePreservesMetadata() {
        let line = TaskMarkdown.serializeLine(
            indent: "",
            bullet: "-",
            isDone: false,
            text: "Buy milk",
            priority: 1,
            deadline: TaskMarkdown.parseDeadline("2026-10-20")
        )
        XCTAssertEqual(line, "- [ ] Buy milk !1 @2026-10-20")
    }

    func testSetPriorityAndDeadlineRewrite() {
        let body = "- [ ] Buy milk\n"
        let withP = TaskMarkdown.setPriority(in: body, lineIndex: 0, priority: 2)
        XCTAssertEqual(withP, "- [ ] Buy milk !2\n")

        let withDue = TaskMarkdown.setDeadline(
            in: withP!,
            lineIndex: 0,
            deadline: TaskMarkdown.parseDeadline("2026-11-01")
        )
        XCTAssertEqual(withDue, "- [ ] Buy milk !2 @2026-11-01\n")

        let clearedP = TaskMarkdown.setPriority(in: withDue!, lineIndex: 0, priority: nil)
        XCTAssertEqual(clearedP, "- [ ] Buy milk @2026-11-01\n")

        let clearedDue = TaskMarkdown.setDeadline(in: clearedP!, lineIndex: 0, deadline: nil)
        XCTAssertEqual(clearedDue, "- [ ] Buy milk\n")
    }

    func testTasksExtractedFromNoteBody() {
        let note = Note(
            fileURL: URL(fileURLWithPath: "/tmp/list.md"),
            title: "list",
            body: """
            Intro
            - [ ] One !1
            - [x] Two @2026-10-01
            Done section
            """,
            tags: [],
            createdAt: .now,
            updatedAt: .now
        )
        let tasks = TaskMarkdown.tasks(in: note)
        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(tasks[0].lineIndex, 1)
        XCTAssertEqual(tasks[0].text, "One")
        XCTAssertEqual(tasks[0].priority, 1)
        XCTAssertFalse(tasks[0].isDone)
        XCTAssertEqual(tasks[1].lineIndex, 2)
        XCTAssertTrue(tasks[1].isDone)
        XCTAssertEqual(TaskMarkdown.formatDeadline(tasks[1].deadline!), "2026-10-01")
    }

    func testToggleCheckboxFlipsMarkerKeepsMetadata() {
        let body = "- [ ] Buy milk !1 @2026-10-20\n- [x] Ship\n"
        let toggledOpen = TaskMarkdown.toggleCheckbox(in: body, lineIndex: 0)
        XCTAssertEqual(toggledOpen, "- [x] Buy milk !1 @2026-10-20\n- [x] Ship\n")

        let toggledDone = TaskMarkdown.toggleCheckbox(in: body, lineIndex: 1)
        XCTAssertEqual(toggledDone, "- [ ] Buy milk !1 @2026-10-20\n- [ ] Ship\n")
    }

    func testToggleNonTaskIsNil() {
        XCTAssertNil(TaskMarkdown.toggleCheckbox(in: "hello\nworld\n", lineIndex: 0))
        XCTAssertNil(TaskMarkdown.toggleCheckbox(in: "- [ ] only\n", lineIndex: 5))
    }

    func testOpenTaskBodyFormat() {
        XCTAssertEqual(TaskMarkdown.openTaskBody(text: "Buy milk"), "- [ ] Buy milk\n")
        XCTAssertEqual(TaskMarkdown.openTaskBody(text: "  "), "- [ ] Untitled\n")
    }

    func testInsertOpenTaskOnEmptyLine() {
        let body = "hello\n\nworld"
        // Caret on the empty middle line (after "hello\n").
        let offset = ("hello\n" as NSString).length
        let result = TaskMarkdown.insertOpenTask(in: body, utf16Offset: offset)
        XCTAssertEqual(result.body, "hello\n- [ ] \nworld")
        let middle = result.body.split(separator: "\n", omittingEmptySubsequences: false)[1]
        XCTAssertEqual(String(middle), "- [ ] ")
    }

    func testInsertOpenTaskBelowCurrentLine() {
        let body = "note line"
        let result = TaskMarkdown.insertOpenTask(in: body, utf16Offset: 0)
        XCTAssertEqual(result.body, "note line\n- [ ] ")
    }

    func testInsertOpenTaskAboveCurrentLine() {
        let body = "note line"
        let result = TaskMarkdown.insertOpenTask(in: body, utf16Offset: 0, above: true)
        XCTAssertEqual(result.body, "- [ ] \nnote line")
    }

    func testLineIndexForUTF16Offset() {
        let body = "a\n- [ ] task\n"
        XCTAssertEqual(TaskMarkdown.lineIndex(forUTF16Offset: 0, in: body), 0)
        XCTAssertEqual(TaskMarkdown.lineIndex(forUTF16Offset: 2, in: body), 1)
        XCTAssertEqual(TaskMarkdown.lineIndex(forUTF16Offset: 8, in: body), 1)
    }

    func testRankTasksEmptyQueryPutsOpenFirst() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        let tasks = [
            TaskItem(
                noteURL: URL(fileURLWithPath: "/tmp/a.md"),
                noteTitle: "a",
                noteUpdatedAt: older,
                lineIndex: 0,
                text: "done item",
                isDone: true
            ),
            TaskItem(
                noteURL: URL(fileURLWithPath: "/tmp/b.md"),
                noteTitle: "b",
                noteUpdatedAt: newer,
                lineIndex: 0,
                text: "open item",
                isDone: false
            ),
        ]
        let ranked = FuzzySearch.rankTasks(tasks, query: "")
        XCTAssertEqual(ranked.count, 2)
        XCTAssertEqual(ranked[0].task.text, "open item")
        XCTAssertTrue(ranked[0].matchesQuery)
        XCTAssertEqual(ranked[1].task.text, "done item")
        XCTAssertFalse(ranked[1].matchesQuery)
    }

    func testRankTasksSortsByPriorityThenDeadline() {
        let day1 = TaskMarkdown.parseDeadline("2026-10-01")!
        let day2 = TaskMarkdown.parseDeadline("2026-10-02")!
        let tasks = [
            TaskItem(
                noteURL: URL(fileURLWithPath: "/tmp/a.md"),
                noteTitle: "a",
                noteUpdatedAt: .now,
                lineIndex: 0,
                text: "low soon",
                isDone: false,
                priority: 3,
                deadline: day1
            ),
            TaskItem(
                noteURL: URL(fileURLWithPath: "/tmp/b.md"),
                noteTitle: "b",
                noteUpdatedAt: .now,
                lineIndex: 0,
                text: "high later",
                isDone: false,
                priority: 1,
                deadline: day2
            ),
            TaskItem(
                noteURL: URL(fileURLWithPath: "/tmp/c.md"),
                noteTitle: "c",
                noteUpdatedAt: .now,
                lineIndex: 0,
                text: "high sooner",
                isDone: false,
                priority: 1,
                deadline: day1
            ),
        ]
        let ranked = FuzzySearch.rankTasks(tasks, query: "")
        XCTAssertEqual(ranked.map(\.task.text), ["high sooner", "high later", "low soon"])
    }

    func testRankTasksMatchesQueryText() {
        let tasks = [
            TaskItem(
                noteURL: URL(fileURLWithPath: "/tmp/a.md"),
                noteTitle: "chores",
                noteUpdatedAt: .now,
                lineIndex: 0,
                text: "Buy milk",
                isDone: false
            ),
            TaskItem(
                noteURL: URL(fileURLWithPath: "/tmp/b.md"),
                noteTitle: "work",
                noteUpdatedAt: .now,
                lineIndex: 0,
                text: "Ship PR",
                isDone: false
            ),
        ]
        let ranked = FuzzySearch.rankTasks(tasks, query: "milk")
        XCTAssertTrue(ranked[0].matchesQuery)
        XCTAssertEqual(ranked[0].task.text, "Buy milk")
        XCTAssertFalse(ranked[1].matchesQuery)
        XCTAssertEqual(FuzzySearch.navigableIndices(in: ranked, query: "milk"), [0])
    }
}
