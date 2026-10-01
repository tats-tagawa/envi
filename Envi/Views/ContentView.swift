import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: NotesFolderStore
    @State private var searchText = ""
    @State private var highlightedIndex = 0
    @FocusState private var editorFocus: EditorFocusTarget?
    @AppStorage("layoutMode") private var layoutMode = LayoutMode.sidebar.rawValue

    /// Ranked once here and passed into the sidebar so both stay in sync.
    private var rankedNotes: [RankedNote] {
        FuzzySearch.rank(store.notes, query: searchText)
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
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in
            focusSearch()
        }
    }

    @ViewBuilder
    private var mainLayout: some View {
        Group {
            switch resolvedLayoutMode {
            case .sidebar:
                HStack(spacing: 0) {
                    notesPane
                        .frame(width: 280)
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
            rankedNotes: rankedNotes,
            searchText: $searchText,
            highlightedIndex: $highlightedIndex,
            editorFocus: $editorFocus,
            selectedNoteID: store.selectedNoteID,
            onMoveHighlight: moveHighlight,
            onOpenHighlightedIntoBody: openHighlightedIntoBody,
            onCreateFromSearch: createFromSearch,
            onSelectIndex: selectIndex
        )
    }

    private var editorPane: some View {
        VStack(spacing: 0) {
            NoteEditorView(
                store: store,
                note: store.selectedNote,
                editorFocus: $editorFocus
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            StatusBarView(note: store.selectedNote)
        }
    }

    private func focusSearch() {
        editorFocus = .search
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }

    private func moveHighlight(by delta: Int) {
        let navigable = FuzzySearch.navigableIndices(in: rankedNotes, query: searchText)
        guard !navigable.isEmpty else {
            highlightedIndex = 0
            return
        }

        let currentPos = navigable.firstIndex(of: highlightedIndex) ?? 0
        let nextPos = min(max(currentPos + delta, 0), navigable.count - 1)
        selectIndex(navigable[nextPos])
    }

    private func selectIndex(_ index: Int) {
        guard rankedNotes.indices.contains(index) else { return }
        highlightedIndex = index
        store.select(rankedNotes[index].note)
    }

    private func openHighlightedIntoBody() {
        let navigable = FuzzySearch.navigableIndices(in: rankedNotes, query: searchText)
        guard !navigable.isEmpty else { return }

        if !navigable.contains(highlightedIndex) {
            highlightedIndex = navigable[0]
        }
        guard rankedNotes.indices.contains(highlightedIndex) else { return }

        store.select(rankedNotes[highlightedIndex].note)
        editorFocus = .body
        // Defer so the body view exists and the title field can resign first.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .focusNoteBodyAtEnd, object: nil)
        }
    }

    private func createFromSearch() {
        let title = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if let note = store.createNote(title: title) {
            searchText = note.title
            if let idx = rankedNotes.firstIndex(where: { $0.note.fileURL == note.fileURL }) {
                highlightedIndex = idx
            }
            store.select(note)
        }
    }

    private func syncSelectionToHighlight() {
        let navigable = FuzzySearch.navigableIndices(in: rankedNotes, query: searchText)
        guard let first = navigable.first else { return }
        if store.selectedNoteID == nil {
            selectIndex(first)
        }
    }
}
