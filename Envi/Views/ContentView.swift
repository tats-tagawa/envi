import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: NotesFolderStore
    @State private var searchText = ""
    @State private var savedSearchText = ""
    @State private var isShowingSelectedTitle = false
    @State private var isRenaming = false
    @State private var isSettingSearchProgrammatically = false
    @State private var highlightedIndex = 0
    @State private var sortOrder: [KeyPathComparator<RankedNote>] = [
        .init(\.note.updatedAt, order: .reverse)
    ]
    @State private var isEditingTags = false
    @State private var tagsDraft = ""
    @FocusState private var editorFocus: EditorFocusTarget?
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.sidebar.rawValue

    /// Rank against the active search query. When the field is showing a selected
    /// note's title (or mid-rename), keep using `savedSearchText` so ↑↓ / ⌃J/K
    /// does not reshuffle the list.
    private var rankingQuery: String {
        if isShowingSelectedTitle || isRenaming {
            return savedSearchText
        }
        return searchText
    }

    private var rankedNotes: [RankedNote] {
        FuzzySearch.rank(store.notes, query: rankingQuery)
    }

    private var displayedNotes: [RankedNote] {
        let ranked = rankedNotes
        let trimmed = rankingQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !sortOrder.isEmpty {
            return ranked.sorted(using: sortOrder)
        }
        return ranked
    }

    private var resolvedLayoutMode: LayoutMode {
        LayoutMode(rawValue: layoutMode) ?? .sidebar
    }

    var body: some View {
        Group {
            if store.hasFolder {
                mainLayout
            } else {
                FolderPickerView(store: store)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .alert(
            "Error",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .background(WindowCloseGuard())
        .background(ControlNoteNavigationMonitor())
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            focusSearch(selectAll: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deselectRestoreSearch)) { _ in
            deselectRestoreSearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .renameSelectedNote)) { _ in
            beginRenameSelected()
        }
        .onReceive(NotificationCenter.default.publisher(for: .editTags)) { _ in
            beginEditTagsSelected()
        }
        .onChange(of: store.selectedNote?.title) { _, newTitle in
            if isShowingSelectedTitle, !isRenaming, let newTitle, searchText != newTitle {
                setSearchProgrammatically(newTitle)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .moveNoteHighlight)) { note in
            let delta = note.userInfo?[NoteHighlightDelta.userInfoKey] as? Int ?? 0
            moveHighlight(by: delta)
        }
        .sheet(isPresented: $isEditingTags) {
            TagEditorSheet(
                noteTitle: store.selectedNote?.title ?? "",
                tagsText: $tagsDraft,
                onCancel: { isEditingTags = false },
                onSave: {
                    commitTagsDraft()
                    isEditingTags = false
                }
            )
        }
    }

    @ViewBuilder
    private var mainLayout: some View {
        Group {
            switch resolvedLayoutMode {
            case .sidebar:
                HStack(spacing: 0) {
                    notesPane
                        .frame(minWidth: 320, idealWidth: 380, maxWidth: 520)
                        .frame(maxHeight: .infinity)

                    Divider()

                    editorPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .stacked:
                VSplitView {
                    notesPane
                        .frame(minHeight: 160)
                        .frame(maxWidth: .infinity)

                    editorPane
                        .frame(minHeight: 200)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            editorFocus = .search
            syncSelectionToHighlight()
        }
    }

    private var notesPane: some View {
        SidebarView(
            displayedNotes: displayedNotes,
            searchText: $searchText,
            highlightedIndex: $highlightedIndex,
            sortOrder: $sortOrder,
            editorFocus: $editorFocus,
            selectedNoteID: store.selectedNoteID,
            rankingQuery: rankingQuery,
            onMoveHighlight: moveHighlight,
            onActivateSearch: activateSearch,
            onSelectIndex: selectIndex,
            onHighlightIndex: highlightIndex,
            onSearchEdited: handleSearchEdited,
            onClearSearch: clearSearch,
            onBeginRename: beginRename(at:),
            onBeginEditTags: beginEditTags(at:)
        )
    }

    private var editorPane: some View {
        NoteEditorView(
            store: store,
            note: store.selectedNote,
            editorFocus: $editorFocus
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search / title field (NV model)

    private func handleSearchEdited() {
        guard !isSettingSearchProgrammatically else { return }
        if isShowingSelectedTitle, !isRenaming {
            if let selected = store.selectedNote, searchText == selected.title {
                return
            }
            // User started a new search from a selected title.
            isShowingSelectedTitle = false
        }
    }

    private func setSearchProgrammatically(_ text: String) {
        isSettingSearchProgrammatically = true
        searchText = text
        DispatchQueue.main.async {
            isSettingSearchProgrammatically = false
        }
    }

    private func adoptSearchTitle(from note: Note) {
        if !isShowingSelectedTitle {
            savedSearchText = searchText
        }
        isShowingSelectedTitle = true
        isRenaming = false
        if searchText != note.title {
            setSearchProgrammatically(note.title)
        }
    }

    private func clearSearch() {
        isRenaming = false
        isShowingSelectedTitle = false
        setSearchProgrammatically("")
        focusSearch(selectAll: false)
    }

    private func deselectRestoreSearch() {
        isRenaming = false
        isShowingSelectedTitle = false
        store.select(nil)
        setSearchProgrammatically(savedSearchText)
        focusSearch(selectAll: true)
    }

    private func beginRenameSelected() {
        guard store.selectedNote != nil else { return }
        if let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == store.selectedNoteID }) {
            beginRename(at: idx)
        }
    }

    private func beginRename(at index: Int) {
        selectIndex(index)
        guard let note = store.selectedNote else { return }
        isRenaming = true
        isShowingSelectedTitle = true
        setSearchProgrammatically(note.title)
        focusSearch(selectAll: true)
    }

    private func beginEditTagsSelected() {
        guard store.selectedNote != nil else { return }
        if let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == store.selectedNoteID }) {
            beginEditTags(at: idx)
        }
    }

    private func beginEditTags(at index: Int) {
        selectIndex(index)
        guard let note = store.selectedNote else { return }
        tagsDraft = note.tags.joined(separator: ", ")
        isEditingTags = true
    }

    private func commitTagsDraft() {
        guard let note = store.selectedNote else { return }
        let tags = tagsDraft
            .split(separator: ",")
            .map { String($0) }
        store.updateTags(tags, for: note.fileURL)
    }

    private func commitRenameIfNeeded() -> Bool {
        guard isRenaming, let note = store.selectedNote else { return false }
        let title = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateTitle(title, for: note.fileURL)
        isRenaming = false
        if let selected = store.selectedNote {
            adoptSearchTitle(from: selected)
        }
        focusBodyAtEnd()
        return true
    }

    private func focusSearch(selectAll: Bool) {
        editorFocus = .search
        guard selectAll else { return }
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }

    // MARK: - Navigation

    private func moveHighlight(by delta: Int) {
        let navigable = FuzzySearch.navigableIndices(in: displayedNotes, query: rankingQuery)
        guard !navigable.isEmpty else {
            highlightedIndex = 0
            return
        }

        let currentPos = navigable.firstIndex(of: highlightedIndex) ?? 0
        let nextPos = min(max(currentPos + delta, 0), navigable.count - 1)
        selectIndex(navigable[nextPos])
    }

    private func selectIndex(_ index: Int) {
        guard displayedNotes.indices.contains(index) else { return }
        highlightedIndex = index
        let note = displayedNotes[index].note
        store.select(note)
        adoptSearchTitle(from: note)
    }

    /// Keep store selection aligned with the highlight while the user is typing a query.
    private func highlightIndex(_ index: Int) {
        guard displayedNotes.indices.contains(index) else { return }
        highlightedIndex = index
        let note = displayedNotes[index].note
        store.select(note)
        if isShowingSelectedTitle {
            adoptSearchTitle(from: note)
        }
    }

    /// Return in the search field: finish rename, open a match, or create when nothing matches.
    private func activateSearch() {
        if commitRenameIfNeeded() { return }

        let navigable = FuzzySearch.navigableIndices(in: displayedNotes, query: rankingQuery)
        // While showing a selected title with an empty ranking query, Return edits the body.
        if isShowingSelectedTitle, store.selectedNote != nil {
            focusBodyAtEnd()
            return
        }

        if navigable.isEmpty {
            createFromSearch()
            return
        }

        if !navigable.contains(highlightedIndex) {
            highlightedIndex = navigable[0]
        }
        guard displayedNotes.indices.contains(highlightedIndex) else { return }

        let note = displayedNotes[highlightedIndex].note
        store.select(note)
        adoptSearchTitle(from: note)
        focusBodyAtEnd()
    }

    private func createFromSearch() {
        let title = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let note = store.createNote(title: title) else { return }
        // NV keeps the new title in the search/title field.
        savedSearchText = ""
        isShowingSelectedTitle = true
        isRenaming = false
        setSearchProgrammatically(note.title)
        if let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == note.fileURL }) {
            highlightedIndex = idx
        }
        store.select(note)
        focusBodyAtEnd()
    }

    private func focusBodyAtEnd() {
        editorFocus = .body
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .focusNoteBodyAtEnd, object: nil)
        }
    }

    private func syncSelectionToHighlight() {
        let navigable = FuzzySearch.navigableIndices(in: displayedNotes, query: rankingQuery)
        guard let first = navigable.first else { return }
        if store.selectedNoteID == nil {
            selectIndex(first)
        } else if let selected = store.selectedNote {
            adoptSearchTitle(from: selected)
            if let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == selected.fileURL }) {
                highlightedIndex = idx
            }
        }
    }
}

private struct TagEditorSheet: View {
    let noteTitle: String
    @Binding var tagsText: String
    var onCancel: () -> Void
    var onSave: () -> Void
    @FocusState private var tagsFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tags")
                .font(.headline)
            Text(noteTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            TextField("Comma-separated tags", text: $tagsText)
                .textFieldStyle(.roundedBorder)
                .focused($tagsFieldFocused)
                .onSubmit(onSave)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            tagsFieldFocused = true
        }
    }
}

/// ⌃J/⌃K and ⌃N/⌃P move the note highlight even when focus is in the body.
private struct ControlNoteNavigationMonitor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.start()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var monitor: Any?

        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                guard flags == .control else { return event }
                let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
                switch key {
                case "j", "n":
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: 1))
                    return nil
                case "k", "p":
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: -1))
                    return nil
                default:
                    return event
                }
            }
        }

        func stop() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit { stop() }
    }
}

/// When a global hotkey is enabled, closing the window hides it instead of quitting.
private struct WindowCloseGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.delegate = context.coordinator
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if UserDefaults.standard.bool(forKey: HotKeyDefaults.enabledKey) {
                sender.orderOut(nil)
                return false
            }
            return true
        }
    }
}
