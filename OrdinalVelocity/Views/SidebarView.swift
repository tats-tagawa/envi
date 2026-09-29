import SwiftUI

struct SidebarView: View {
    @Bindable var store: NotesFolderStore
    @Binding var searchText: String
    @Binding var highlightedIndex: Int
    var searchFocused: FocusState<Bool>.Binding
    var onMoveHighlight: (Int) -> Void
    var onOpenHighlighted: () -> Void
    var onCreateFromSearch: () -> Void

    private var filtered: [Note] {
        FuzzySearch.filter(store.notes, query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search or create…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .focused(searchFocused)
                .padding(8)
                .onKeyPress { keyPress in
                    handleKey(keyPress)
                }

            List(Array(filtered.enumerated()), id: \.element.id) { index, note in
                NoteRow(note: note, isHighlighted: index == highlightedIndex)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        highlightedIndex = index
                        store.select(note)
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
                onOpenHighlighted()
            }
            return .handled
        }
        return .ignored
    }

    private func reconcileHighlight(keeping preferredID: URL?) {
        let items = filtered
        guard !items.isEmpty else {
            highlightedIndex = 0
            return
        }
        if let preferredID, let idx = items.firstIndex(where: { $0.fileURL == preferredID }) {
            highlightedIndex = idx
        } else {
            highlightedIndex = min(max(highlightedIndex, 0), items.count - 1)
        }
    }
}

private struct NoteRow: View {
    let note: Note
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.body.weight(isHighlighted ? .semibold : .regular))
                .lineLimit(1)
            if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
