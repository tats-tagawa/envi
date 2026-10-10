import XCTest
@testable import Envi

@MainActor
final class NotesFolderStoreTests: XCTestCase {
    private static let bookmarkKey = "notesFolderBookmark"

    private var folder: URL!
    private var store: NotesFolderStore!
    private var previousBookmark: Data?

    override func setUp() async throws {
        previousBookmark = UserDefaults.standard.data(forKey: Self.bookmarkKey)
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("envi-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bookmark = try folder.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        store = NotesFolderStore()
        XCTAssertEqual(
            store.folderURL?.resolvingSymlinksInPath().path,
            folder.resolvingSymlinksInPath().path
        )
    }

    override func tearDown() async throws {
        store?.flushPendingSaves()
        if let folder {
            try? FileManager.default.removeItem(at: folder)
        }
        if let previousBookmark {
            UserDefaults.standard.set(previousBookmark, forKey: Self.bookmarkKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        }
        folder = nil
        store = nil
        previousBookmark = nil
    }

    func testFlushPersistsPendingBodyEdits() async throws {
        let note = try XCTUnwrap(store.createNote(title: "Flush Me"))
        store.updateBody("unsaved yet", for: note.fileURL)
        store.flushPendingSaves()

        let disk = try String(contentsOf: note.fileURL, encoding: .utf8)
        XCTAssertEqual(disk, "unsaved yet")
    }

    func testDeleteMovesFileToTrash() throws {
        let note = try XCTUnwrap(store.createNote(title: "Trash Me"))
        let url = note.fileURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        store.deleteNote(url)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertNil(store.notes.first(where: { $0.fileURL == url }))
    }

    func testRenameCollisionReportsOutcome() throws {
        _ = try XCTUnwrap(store.createNote(title: "Taken"))
        let second = try XCTUnwrap(store.createNote(title: "Other"))
        let outcome = store.updateTitle("Taken", for: second.fileURL)
        guard case .collided(let actual) = outcome else {
            return XCTFail("Expected collision, got \(outcome)")
        }
        XCTAssertEqual(actual, "Taken 2")
    }

    func testFlushNotificationPersistsBeforeReturn() throws {
        let note = try XCTUnwrap(store.createNote(title: "Quit"))
        store.updateBody("still typing", for: note.fileURL)
        NotificationCenter.default.post(name: .flushPendingNotes, object: nil)
        let disk = try String(contentsOf: note.fileURL, encoding: .utf8)
        XCTAssertEqual(disk, "still typing")
    }

    func testSuppressedReloadAppliesWhenWindowEnds() async throws {
        _ = try XCTUnwrap(store.createNote(title: "Keep"))
        let other = folder.appendingPathComponent("External.md")
        try "from outside".write(to: other, atomically: true, encoding: .utf8)
        store.reloadNotes()
        XCTAssertNil(store.notes.first { $0.title == "External" })

        try await Task.sleep(for: .seconds(2.6))
        XCTAssertEqual(store.notes.first { $0.title == "External" }?.body, "from outside")
    }

    func testFailedSaveStaysInMemoryAcrossReload() async throws {
        let note = try XCTUnwrap(store.createNote(title: "Locked"))
        store.flushPendingSaves()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: folder.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: folder.path
            )
        }

        store.updateBody("kept in memory", for: note.fileURL)
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(store.notes.first { $0.fileURL == note.fileURL }?.body, "kept in memory")
        XCTAssertNotNil(store.errorMessage)

        try await Task.sleep(for: .seconds(2.2))
        store.reloadNotes()
        XCTAssertEqual(store.notes.first { $0.fileURL == note.fileURL }?.body, "kept in memory")
        let disk = try String(contentsOf: note.fileURL, encoding: .utf8)
        XCTAssertNotEqual(disk, "kept in memory")
    }

    func testInvalidUTF8IsLeftUnchanged() throws {
        let url = folder.appendingPathComponent("Bad.md")
        let bytes: [UInt8] = [0xFF, 0xFE, 0x00, 0x41]
        try Data(bytes).write(to: url)
        store.reloadNotes()
        XCTAssertNil(store.notes.first { $0.fileURL == url })
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual([UInt8](try Data(contentsOf: url)), bytes)
    }

    func testSavePreservesUnknownFrontmatter() throws {
        let url = folder.appendingPathComponent("Kept.md")
        let raw = """
        ---
        title: Hello
        tags:
          - work
          - ideas
        ---
        Body
        """
        try raw.write(to: url, atomically: true, encoding: .utf8)
        store.reloadNotes()
        let note = try XCTUnwrap(store.notes.first { $0.title == "Kept" })
        XCTAssertEqual(note.tags, ["work", "ideas"])
        XCTAssertEqual(note.body, "Body")
        store.updateTags(["work"], for: note.fileURL)
        store.flushPendingSaves()
        let disk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(disk.contains("title: Hello"))
        XCTAssertTrue(disk.contains("tags: work"))
        XCTAssertFalse(disk.contains("ideas"))
    }
}
