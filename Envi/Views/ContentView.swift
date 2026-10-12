import AppKit
import SwiftUI

/// How the search field relates to the selected note (NV model).
private enum SearchFieldMode: Equatable {
    /// User is typing a filter query.
    case querying
    /// Field shows the selected note's title (not editing the filename).
    case showingTitle
}

struct ContentView: View {
    @Bindable var store: NotesFolderStore
    @State private var searchText = ""
    @State private var savedSearchText = ""
    @State private var searchMode: SearchFieldMode = .querying
    @State private var isSettingSearchProgrammatically = false
    @State private var highlightedIndex = 0
    @State private var sortOrder: [KeyPathComparator<RankedNote>] = [
        .init(\.note.updatedAt, order: .reverse)
    ]
    @State private var listInlineEdit: ResultsInlineEdit?
    @State private var notePendingDeletion: Note?
    @State private var renameCollisionMessage: String?
    @FocusState private var editorFocus: EditorFocusTarget?
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.sidebar.rawValue
    /// Fresh key so prior default-on installs pick up Vim-off without a Settings visit.
    @AppStorage("vimModeEnabled") private var vimModeEnabled = false
    @State private var vimMode: VimMode = .insert

    /// Rank against the active search query. When the field is showing a selected
    /// note's title, keep using `savedSearchText` so ↑↓ / ⌘J/K does not reshuffle the list.
    private var rankingQuery: String {
        switch searchMode {
        case .showingTitle:
            return savedSearchText
        case .querying:
            return searchText
        }
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

    /// Sidebar needs room for two panes; stacked can be narrower.
    private var windowMinWidth: CGFloat {
        switch resolvedLayoutMode {
        case .sidebar: 720
        case .stacked: 480
        }
    }

    var body: some View {
        Group {
            if store.hasFolder {
                mainLayout
            } else {
                FolderPickerView(store: store)
            }
        }
        .frame(minWidth: windowMinWidth, minHeight: 480)
        .background(WindowContentMinSize(minWidth: windowMinWidth, minHeight: 480))
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
        .alert(
            "Delete Note?",
            isPresented: Binding(
                get: { notePendingDeletion != nil },
                set: { if !$0 { notePendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { notePendingDeletion = nil }
            Button("Move to Trash", role: .destructive) {
                if let note = notePendingDeletion {
                    store.deleteNote(note.fileURL)
                    if searchMode != .querying {
                        searchMode = .querying
                        setSearchProgrammatically(savedSearchText)
                    }
                }
                notePendingDeletion = nil
            }
        } message: {
            Text("“\(notePendingDeletion?.title ?? "")” will be moved to the Trash.")
        }
        .alert(
            "Title Already Used",
            isPresented: Binding(
                get: { renameCollisionMessage != nil },
                set: { if !$0 { renameCollisionMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { renameCollisionMessage = nil }
        } message: {
            Text(renameCollisionMessage ?? "")
        }
        .background(WindowCloseGuard())
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
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedNote)) { _ in
            beginDeleteSelected()
        }
        .onChange(of: store.selectedNote?.title) { _, newTitle in
            if searchMode == .showingTitle, let newTitle, searchText != newTitle {
                setSearchProgrammatically(newTitle)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .moveNoteHighlight)) { note in
            let delta = note.userInfo?[NoteHighlightDelta.userInfoKey] as? Int ?? 0
            moveHighlight(by: delta)
        }
    }

    @ViewBuilder
    private var mainLayout: some View {
        Group {
            switch resolvedLayoutMode {
            case .sidebar:
                HSplitView {
                    notesPane
                        .frame(minWidth: 240, idealWidth: 380)
                        .frame(maxHeight: .infinity)

                    editorPane
                        .frame(minWidth: 320)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .stacked:
                VSplitView {
                    notesPane
                        .frame(minHeight: 140, idealHeight: 200)
                        .frame(maxWidth: .infinity)

                    editorPane
                        .frame(minHeight: 240)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        // Tear down HSplitView/VSplitView so pane min-widths do not stick on the window.
        .id(resolvedLayoutMode)
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
            inlineEdit: $listInlineEdit,
            editorFocus: $editorFocus,
            selectedNoteID: store.selectedNoteID,
            rankingQuery: rankingQuery,
            onMoveHighlight: moveHighlight,
            onActivateSearch: activateSearch,
            onSelectIndex: selectIndex,
            onHighlightIndex: highlightIndex,
            onSearchEdited: handleSearchEdited,
            onClearSearch: clearSearch,
            onCommitTitle: commitListTitle,
            onCommitTags: commitListTags,
            onBeginDelete: beginDelete(at:),
            reconcileSearchChanges: !isSettingSearchProgrammatically,
            emphasizeSelection: editorFocus == .search || editorFocus == nil
        )
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            NoteEditorView(
                store: store,
                note: store.selectedNote,
                editorFocus: $editorFocus,
                vimEnabled: vimModeEnabled,
                vimMode: $vimMode
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if vimModeEnabled {
                StatusBarView(vimMode: vimMode)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Search / title field (NV model)

    private func handleSearchEdited() {
        guard !isSettingSearchProgrammatically else { return }
        if searchMode == .showingTitle {
            if let selected = store.selectedNote, searchText == selected.title {
                return
            }
            // User started a new search from a selected title.
            searchMode = .querying
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
        if searchMode == .querying {
            savedSearchText = searchText
        }
        searchMode = .showingTitle
        if searchText != note.title {
            setSearchProgrammatically(note.title)
        }
    }

    private func clearSearch() {
        searchMode = .querying
        setSearchProgrammatically("")
        focusSearch(selectAll: false)
    }

    private func deselectRestoreSearch() {
        searchMode = .querying
        store.select(nil)
        setSearchProgrammatically(savedSearchText)
        focusSearch(selectAll: true)
    }

    private func beginRenameSelected() {
        guard let id = store.selectedNoteID,
              let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == id }) else { return }
        selectIndex(idx)
        listInlineEdit = .title(id)
    }

    private func beginEditTagsSelected() {
        guard let id = store.selectedNoteID,
              let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == id }) else { return }
        selectIndex(idx)
        listInlineEdit = .tags(id)
    }

    private func beginDeleteSelected() {
        guard let note = store.selectedNote else { return }
        notePendingDeletion = note
    }

    private func beginDelete(at index: Int) {
        guard displayedNotes.indices.contains(index) else { return }
        notePendingDeletion = displayedNotes[index].note
    }

    private func commitListTitle(_ noteID: URL, _ title: String) {
        let outcome = store.updateTitle(title, for: noteID)
        handleRenameOutcome(outcome)
        if searchMode == .showingTitle, let selected = store.selectedNote {
            adoptSearchTitle(from: selected)
        }
    }

    private func commitListTags(_ noteID: URL, _ tagsText: String) {
        let tags = tagsText
            .split(separator: ",")
            .map { String($0) }
        store.updateTags(tags, for: noteID)
    }

    private func handleRenameOutcome(_ outcome: NoteRenameOutcome) {
        if case .collided(let actualTitle) = outcome {
            renameCollisionMessage =
                "That name was already taken. The note was saved as “\(actualTitle)”."
        }
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
        if searchMode == .showingTitle {
            adoptSearchTitle(from: note)
        }
    }

    /// Return in the search field: open a match, or create when nothing matches.
    private func activateSearch() {
        let navigable = FuzzySearch.navigableIndices(in: displayedNotes, query: rankingQuery)
        // While showing a selected title with an empty ranking query, Return edits the body.
        if searchMode == .showingTitle, store.selectedNote != nil {
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
        searchMode = .showingTitle
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
            // Keep an empty selection on launch; only sync highlight index.
            highlightedIndex = first
        } else if let selected = store.selectedNote {
            adoptSearchTitle(from: selected)
            if let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == selected.fileURL }) {
                highlightedIndex = idx
            }
        }
    }
}

/// Keeps `NSWindow.contentMinSize` in sync when layout mode changes.
/// SwiftUI's `.frame(minWidth:)` alone does not always clear an HSplitView minimum.
private struct WindowContentMinSize: NSViewRepresentable {
    var minWidth: CGFloat
    var minHeight: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let size = NSSize(width: minWidth, height: minHeight)
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            if window.contentMinSize != size {
                window.contentMinSize = size
            }
        }
    }
}

/// When a global hotkey is enabled, closing the window hides it instead of quitting.
/// Chains the previous window delegate so SwiftUI's own delegate is preserved.
private struct WindowCloseGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, NSWindowDelegate {
        private weak var window: NSWindow?
        private weak var previousDelegate: NSWindowDelegate?

        func attach(to window: NSWindow?) {
            guard let window else { return }
            if self.window === window { return }
            detach()
            self.window = window
            previousDelegate = window.delegate
            window.delegate = self
        }

        func detach() {
            if let window, window.delegate === self {
                window.delegate = previousDelegate
            }
            window = nil
            previousDelegate = nil
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if UserDefaults.standard.bool(forKey: HotKeyDefaults.enabledKey) {
                sender.orderOut(nil)
                return false
            }
            if let previousDelegate {
                return previousDelegate.windowShouldClose?(sender) ?? true
            }
            return true
        }

        override func responds(to aSelector: Selector!) -> Bool {
            if super.responds(to: aSelector) { return true }
            return previousDelegate?.responds(to: aSelector) ?? false
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            previousDelegate
        }
    }
}
