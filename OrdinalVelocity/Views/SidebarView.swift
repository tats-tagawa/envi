import SwiftUI

struct SidebarView: View {
    @Bindable var store: NotesFolderStore
    @Binding var searchText: String
    @Binding var highlightedIndex: Int
    var editorFocus: FocusState<EditorFocusTarget?>.Binding
    var onMoveHighlight: (Int) -> Void
    var onOpenHighlightedIntoBody: () -> Void
    var onCreateFromSearch: () -> Void
    var onSelectIndex: (Int) -> Void

    private var ranked: [RankedNote] {
        FuzzySearch.rank(store.notes, query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search or create…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused(editorFocus, equals: .search)
                .padding(8)
                .onKeyPress { keyPress in
                    handleKey(keyPress)
                }

            List(Array(ranked.enumerated()), id: \.element.id) { index, rankedNote in
                NoteRow(
                    note: rankedNote.note,
                    isHighlighted: index == highlightedIndex,
                    matchesQuery: rankedNote.matchesQuery
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectIndex(index)
                }
                .listRowBackground(
                    index == highlightedIndex
                        ? Color.accentColor.opacity(0.2)
                        : Color.clear
                )
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: searchText) { _, _ in
            reconcileHighlight(keeping: store.selectedNoteID)
        }
        .onChange(of: store.notes.count) { _, _ in
            reconcileHighlight(keeping: store.selectedNoteID)
        }
    }

    private func handleKey(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.key == .upArrow {
            onMoveHighlight(-1)
            return .handled
        }
        if keyPress.key == .downArrow {
            onMoveHighlight(1)
            return .handled
        }
        if keyPress.modifiers.contains(.control) {
            let c = String(keyPress.characters).lowercased()
            if c == "n" {
                onMoveHighlight(1)
                return .handled
            }
            if c == "p" {
                onMoveHighlight(-1)
                return .handled
            }
        }
        if keyPress.key == .return {
            if keyPress.modifiers.contains(.command) {
                onCreateFromSearch()
            } else {
                onOpenHighlightedIntoBody()
            }
            return .handled
        }
        return .ignored
    }

    private func reconcileHighlight(keeping preferredID: URL?) {
        let items = ranked
        let navigable = FuzzySearch.navigableIndices(in: items, query: searchText)
        guard !navigable.isEmpty else {
            highlightedIndex = 0
            return
        }
        if let preferredID,
           let idx = items.firstIndex(where: { $0.note.fileURL == preferredID }),
           navigable.contains(idx) {
            highlightedIndex = idx
        } else if navigable.contains(highlightedIndex) {
            // keep
        } else {
            highlightedIndex = navigable[0]
        }
        onSelectIndex(highlightedIndex)
    }
}

private struct NoteRow: View {
    let note: Note
    let isHighlighted: Bool
    let matchesQuery: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.body.weight(isHighlighted ? .semibold : .regular))
                .foregroundStyle(matchesQuery ? Color.primary : Color.secondary)
                .lineLimit(1)
            if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.body)
                    .font(.caption)
                    .foregroundStyle(matchesQuery ? Color.secondary : Color.secondary.opacity(0.55))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
