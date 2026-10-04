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
}
