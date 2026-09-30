import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class NotesFolderStore {
    private static let bookmarkKey = "notesFolderBookmark"

    private(set) var notes: [Note] = []
    private(set) var folderURL: URL?
    var selectedNoteID: URL?
    var errorMessage: String?

    private var isAccessingSecurityScope = false
    private var watcher: DirectoryWatcher?
    private var saveTasks: [URL: Task<Void, Never>] = [:]
    /// While set, ignore directory-watcher reloads so our own writes do not bounce back.
    private var suppressReloadUntil: Date?
    private var isReloading = false

    var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.fileURL == selectedNoteID }
    }

    var hasFolder: Bool { folderURL != nil }

    init() {
        restoreBookmark()
    }

    // MARK: - Folder

    func restoreBookmark() {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                if let refreshed = try? url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                ) {
                    UserDefaults.standard.set(refreshed, forKey: Self.bookmarkKey)
                }
            }
            activateFolder(url)
        } catch {
            errorMessage = "Could not reopen notes folder. Choose it again."
            folderURL = nil
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Select"
        panel.message = "Choose a folder for your Markdown notes."
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        beginUsingFolder(url)
    }

    func useDefaultDocumentsFolder() {
        let docs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
        let folder = docs.appendingPathComponent("envi", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            beginUsingFolder(folder)
        } catch {
            errorMessage = "Could not create envi folder: \(error.localizedDescription)"
        }
    }

    private func beginUsingFolder(_ url: URL) {
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            activateFolder(url)
        } catch {
            // Path is already accessible (e.g. default Documents with sandbox off).
            UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
            activateFolder(url)
        }
    }

    private func activateFolder(_ url: URL) {
        if isAccessingSecurityScope {
            folderURL?.stopAccessingSecurityScopedResource()
            isAccessingSecurityScope = false
        }

        let accessed = url.startAccessingSecurityScopedResource()
        isAccessingSecurityScope = accessed
        folderURL = url
        selectedNoteID = nil
        startWatching(url)
        reloadNotes()
    }

    // MARK: - Load / watch

    func reloadNotes() {
        guard let folderURL, !isReloading else { return }
        // Skip reloads right after we wrote or renamed a file (watcher echo).
        if let until = suppressReloadUntil, Date() < until { return }

        isReloading = true
        defer { isReloading = false }

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [
                    .creationDateKey,
                    .contentModificationDateKey,
                    .isRegularFileKey
                ],
                options: [.skipsHiddenFiles]
            )

            var loaded: [Note] = []
            for url in urls where url.pathExtension.lowercased() == "md" {
                let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? true
                guard isFile else { continue }

                // Keep in-memory text if a debounced save for this note is still pending.
                if let selected = selectedNote,
                   selected.fileURL == url,
                   saveTasks[url] != nil {
                    loaded.append(selected)
                    continue
                }

                let body = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                let timestamps = Note.fileTimestamps(for: url)
                let title = url.deletingPathExtension().lastPathComponent
                loaded.append(
                    Note(
                        fileURL: url,
                        title: title,
                        body: body,
                        createdAt: timestamps.created,
                        updatedAt: timestamps.updated
                    )
                )
            }

            notes = loaded.sorted { $0.updatedAt > $1.updatedAt }

            if let selectedNoteID,
               !notes.contains(where: { $0.fileURL == selectedNoteID }) {
                self.selectedNoteID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed to read notes: \(error.localizedDescription)"
        }
    }

    private func startWatching(_ url: URL) {
        watcher?.stop()
        watcher = DirectoryWatcher { [weak self] in
            Task { @MainActor in
                self?.reloadNotes()
            }
        }
        watcher?.watch(url: url)
    }

    // MARK: - CRUD

    @discardableResult
    func createNote(title: String) -> Note? {
        guard let folderURL else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let url = uniqueFileURL(forTitle: trimmed, in: folderURL)
        do {
            try "".write(to: url, atomically: true, encoding: .utf8)
            suppressReloadBriefly()
            let timestamps = Note.fileTimestamps(for: url)
            let note = Note(
                fileURL: url,
                title: url.deletingPathExtension().lastPathComponent,
                body: "",
                createdAt: timestamps.created,
                updatedAt: timestamps.updated
            )
            notes.insert(note, at: 0)
            selectedNoteID = note.fileURL
            return note
        } catch {
            errorMessage = "Could not create note: \(error.localizedDescription)"
            return nil
        }
    }

    func select(_ note: Note?) {
        let newID = note?.fileURL
        // Selecting the same note again should not flush pending saves.
        if newID == selectedNoteID { return }
        flushPendingSaves()
        selectedNoteID = newID
    }

    func updateBody(_ body: String, for noteID: URL) {
        guard let index = notes.firstIndex(where: { $0.fileURL == noteID }) else { return }
        notes[index].body = body
        scheduleSave(noteID: noteID)
    }

    func updateTitle(_ title: String, for noteID: URL) {
        guard let index = notes.firstIndex(where: { $0.fileURL == noteID }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let current = notes[index]
        if current.title == trimmed { return }

        guard let folderURL else { return }
        let destination = uniqueFileURL(forTitle: trimmed, in: folderURL, excluding: current.fileURL)

        flushSave(for: noteID)

        do {
            suppressReloadBriefly()
            try FileManager.default.moveItem(at: current.fileURL, to: destination)
            let timestamps = Note.fileTimestamps(for: destination)
            notes[index].fileURL = destination
            notes[index].title = destination.deletingPathExtension().lastPathComponent
            notes[index].updatedAt = timestamps.updated
            if selectedNoteID == noteID {
                selectedNoteID = destination
            }
        } catch {
            errorMessage = "Could not rename note: \(error.localizedDescription)"
        }
    }

    private func scheduleSave(noteID: URL) {
        saveTasks[noteID]?.cancel()
        saveTasks[noteID] = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistBody(for: noteID)
            saveTasks[noteID] = nil
        }
    }

    private func flushPendingSaves() {
        for id in saveTasks.keys {
            flushSave(for: id)
        }
    }

    private func flushSave(for noteID: URL) {
        saveTasks[noteID]?.cancel()
        saveTasks[noteID] = nil
        persistBody(for: noteID)
    }

    private func persistBody(for noteID: URL) {
        guard let note = notes.first(where: { $0.fileURL == noteID }) else { return }
        do {
            suppressReloadBriefly()
            try note.body.write(to: note.fileURL, atomically: true, encoding: .utf8)
            if let index = notes.firstIndex(where: { $0.fileURL == noteID }) {
                let timestamps = Note.fileTimestamps(for: note.fileURL)
                notes[index].updatedAt = timestamps.updated
                notes[index].createdAt = timestamps.created
            }
        } catch {
            errorMessage = "Could not save note: \(error.localizedDescription)"
        }
    }

    private func suppressReloadBriefly() {
        // Longer than DirectoryWatcher's 0.2s debounce so our write is ignored once.
        suppressReloadUntil = Date().addingTimeInterval(0.5)
    }

    private func uniqueFileURL(forTitle title: String, in folder: URL, excluding: URL? = nil) -> URL {
        let base = sanitizeFilename(title)
        var candidate = folder.appendingPathComponent("\(base).md")
        if candidate == excluding { return candidate }

        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path)
            && candidate != excluding {
            candidate = folder.appendingPathComponent("\(base) \(n).md")
            n += 1
        }
        return candidate
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
}
