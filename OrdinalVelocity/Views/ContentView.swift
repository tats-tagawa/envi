import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: NotesFolderStore
    @State private var searchText = ""
    @State private var highlightedIndex = 0
    @FocusState private var editorFocus: EditorFocusTarget?

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
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            focusSearch()
        }
    }

    private var mainLayout: some View {
        HStack(spacing: 0) {
            SidebarView(
                store: store,
                searchText: $searchText,
                highlightedIndex: $highlightedIndex,
                editorFocus: $editorFocus,
                onMoveHighlight: moveHighlight,
                onOpenHighlightedIntoBody: openHighlightedIntoBody,
                onCreateFromSearch: createFromSearch,
                onSelectIndex: selectIndex
            )
            .frame(width: 280)
            .frame(maxHeight: .infinity)

            Divider()

            VStack(spacing: 0) {
                NoteEditorView(
                    store: store,
                    note: store.selectedNote,
                    editorFocus: $editorFocus
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                StatusBarView(note: store.selectedNote)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            editorFocus = .search
            syncSelectionToHighlight()
        }
        .background {
            Button("") { focusSearch() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    private func focusSearch() {
        editorFocus = .search
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }

    private func rankedNotes() -> [RankedNote] {
        FuzzySearch.rank(store.notes, query: searchText)
    }

    private func moveHighlight(by delta: Int) {
        let ranked = rankedNotes()
        let navigable = FuzzySearch.navigableIndices(in: ranked, query: searchText)
        guard !navigable.isEmpty else {
            highlightedIndex = 0
            return
        }

        let currentPos = navigable.firstIndex(of: highlightedIndex) ?? 0
        let nextPos = min(max(currentPos + delta, 0), navigable.count - 1)
        let nextIndex = navigable[nextPos]
        highlightedIndex = nextIndex
        store.select(ranked[nextIndex].note)
    }

    private func selectIndex(_ index: Int) {
        let ranked = rankedNotes()
        guard ranked.indices.contains(index) else { return }
        highlightedIndex = index
        store.select(ranked[index].note)
    }

    private func openHighlightedIntoBody() {
        let ranked = rankedNotes()
        let navigable = FuzzySearch.navigableIndices(in: ranked, query: searchText)
        guard !navigable.isEmpty else { return }

        if !navigable.contains(highlightedIndex) {
            highlightedIndex = navigable[0]
        }
        guard ranked.indices.contains(highlightedIndex) else { return }

        store.select(ranked[highlightedIndex].note)
        editorFocus = .body
        // Defer so the body view exists / selection syncs before caret placement.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .focusNoteBodyAtEnd, object: nil)
        }
    }

    private func createFromSearch() {
        let title = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if let note = store.createNote(title: title) {
            searchText = note.title
            let ranked = rankedNotes()
            if let idx = ranked.firstIndex(where: { $0.note.fileURL == note.fileURL }) {
                highlightedIndex = idx
            }
            store.select(note)
        }
    }

    private func syncSelectionToHighlight() {
        let ranked = rankedNotes()
        let navigable = FuzzySearch.navigableIndices(in: ranked, query: searchText)
        guard let first = navigable.first, ranked.indices.contains(first) else { return }
        if store.selectedNoteID == nil {
            highlightedIndex = first
            store.select(ranked[first].note)
        }
    }
}
