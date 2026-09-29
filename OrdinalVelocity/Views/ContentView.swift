import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: NotesFolderStore
    @State private var searchText = ""
    @State private var highlightedIndex = 0
    @FocusState private var searchFocused: Bool

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
                searchFocused: $searchFocused,
                onMoveHighlight: moveHighlight,
                onOpenHighlighted: openHighlighted,
                onCreateFromSearch: createFromSearch
            )
            .frame(width: 280)
            .frame(maxHeight: .infinity)

            Divider()

            VStack(spacing: 0) {
                NoteEditorView(store: store, note: store.selectedNote)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                StatusBarView(note: store.selectedNote)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            searchFocused = true
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
        searchFocused = true
        DispatchQueue.main.async {
            NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        }
    }

    private func filteredNotes() -> [Note] {
        FuzzySearch.filter(store.notes, query: searchText)
    }

    private func moveHighlight(by delta: Int) {
        let items = filteredNotes()
        guard !items.isEmpty else {
            highlightedIndex = 0
            return
        }
        highlightedIndex = min(max(highlightedIndex + delta, 0), items.count - 1)
    }

    private func openHighlighted() {
        let items = filteredNotes()
        guard items.indices.contains(highlightedIndex) else { return }
        store.select(items[highlightedIndex])
    }

    private func createFromSearch() {
        let title = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if let note = store.createNote(title: title) {
            searchText = note.title
            if let idx = filteredNotes().firstIndex(where: { $0.fileURL == note.fileURL }) {
                highlightedIndex = idx
            }
        }
    }
}
