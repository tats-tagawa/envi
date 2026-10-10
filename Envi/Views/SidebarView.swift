import AppKit
import SwiftUI

/// Which results-list cell is being edited inline.
enum ResultsInlineEdit: Equatable {
    case title(URL)
    case tags(URL)
}

struct SidebarView: View {
    let displayedNotes: [RankedNote]
    @Binding var searchText: String
    @Binding var highlightedIndex: Int
    @Binding var sortOrder: [KeyPathComparator<RankedNote>]
    @Binding var inlineEdit: ResultsInlineEdit?
    var editorFocus: FocusState<EditorFocusTarget?>.Binding
    var selectedNoteID: URL?
    /// Same query ContentView uses for ranking — keep highlight sync stable while navigating.
    var rankingQuery: String
    var onMoveHighlight: (Int) -> Void
    var onActivateSearch: () -> Void
    /// Explicit click / keyboard selection — fills the search field with the note title.
    var onSelectIndex: (Int) -> Void
    /// Soft highlight sync while typing a search — does not rewrite the search field.
    var onHighlightIndex: (Int) -> Void
    var onSearchEdited: () -> Void
    var onClearSearch: () -> Void
    var onCommitTitle: (URL, String) -> Void
    var onCommitTags: (URL, String) -> Void
    var onBeginDelete: (Int) -> Void

    @State private var editDraft = ""
    @FocusState private var inlineFieldFocused: Bool
    @AppStorage(ModifiedDateOrder.storageKey) private var dateOrder = ModifiedDateOrder.yearMonthDay.rawValue
    @AppStorage(ModifiedDateFormat.use24HourKey) private var use24Hour = false

    private var resolvedDateOrder: ModifiedDateOrder {
        ModifiedDateOrder(rawValue: dateOrder) ?? .yearMonthDay
    }

    private var tableSelection: Binding<Set<RankedNote.ID>> {
        Binding(
            get: {
                guard let selectedNoteID else { return [] }
                return [selectedNoteID]
            },
            set: { newValue in
                guard let id = newValue.first,
                      let index = displayedNotes.firstIndex(where: { $0.id == id }) else { return }
                onSelectIndex(index)
            }
        )
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
                .onChange(of: searchText) { _, _ in
                    onSearchEdited()
                    reconcileHighlight(keeping: selectedNoteID)
                }

            Table(displayedNotes, selection: tableSelection, sortOrder: $sortOrder) {
                TableColumn("Title", value: \.note.title) { ranked in
                    titleCell(for: ranked)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Date Modified", value: \.note.updatedAt) { ranked in
                    Text(
                        ModifiedDateFormat.string(
                            for: ranked.note.updatedAt,
                            order: resolvedDateOrder,
                            use24Hour: use24Hour
                        )
                    )
                        .foregroundStyle(ranked.matchesQuery ? Color.secondary : Color.secondary.opacity(0.55))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(min: 120, ideal: 160)

                TableColumn("Tags", value: \.tagsDisplay) { ranked in
                    tagsCell(for: ranked)
                }
                .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: RankedNote.ID.self) { ids in
                if let id = ids.first,
                   let index = displayedNotes.firstIndex(where: { $0.id == id }) {
                    Button("Rename") { beginInlineEdit(.title(id), at: index) }
                    Button("Edit Tags…") { beginInlineEdit(.tags(id), at: index) }
                    Divider()
                    Button("Move to Trash", role: .destructive) { onBeginDelete(index) }
                }
            }
            .onChange(of: displayedNotes.count) { _, _ in
                reconcileHighlight(keeping: selectedNoteID)
            }
            .onChange(of: sortOrder) { _, _ in
                reconcileHighlight(keeping: selectedNoteID)
            }
            .onChange(of: inlineEdit) { _, newValue in
                guard let newValue else {
                    inlineFieldFocused = false
                    return
                }
                seedDraft(for: newValue)
                DispatchQueue.main.async {
                    inlineFieldFocused = true
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
            }
            .onChange(of: selectedNoteID) { _, newID in
                guard let inlineEdit else { return }
                let editingID: URL = {
                    switch inlineEdit {
                    case .title(let id), .tags(let id): return id
                    }
                }()
                if newID != editingID {
                    commitInlineEdit()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func titleCell(for ranked: RankedNote) -> some View {
        if case .title(let id) = inlineEdit, id == ranked.id {
            inlineEditor(placeholder: "Title")
        } else {
            Text(ranked.note.title)
                .font(.body.weight(ranked.note.fileURL == selectedNoteID ? .semibold : .regular))
                .foregroundStyle(ranked.matchesQuery ? Color.primary : Color.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    guard let index = index(of: ranked) else { return }
                    beginInlineEdit(.title(ranked.id), at: index)
                })
        }
    }

    @ViewBuilder
    private func tagsCell(for ranked: RankedNote) -> some View {
        if case .tags(let id) = inlineEdit, id == ranked.id {
            inlineEditor(placeholder: "Tags")
        } else {
            Text(ranked.tagsDisplay.isEmpty ? " " : ranked.tagsDisplay)
                .foregroundStyle(ranked.matchesQuery ? Color.secondary : Color.secondary.opacity(0.55))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .simultaneousGesture(TapGesture(count: 2).onEnded {
                    guard let index = index(of: ranked) else { return }
                    beginInlineEdit(.tags(ranked.id), at: index)
                })
        }
    }

    private func inlineEditor(placeholder: String) -> some View {
        TextField(placeholder, text: $editDraft)
            .textFieldStyle(.plain)
            .focused($inlineFieldFocused)
            .onSubmit { commitInlineEdit() }
            .onExitCommand { cancelInlineEdit() }
            .onChange(of: inlineFieldFocused) { wasFocused, isFocused in
                if wasFocused, !isFocused, inlineEdit != nil {
                    commitInlineEdit()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func beginInlineEdit(_ target: ResultsInlineEdit, at index: Int) {
        onSelectIndex(index)
        if inlineEdit != target {
            inlineEdit = target
        } else {
            seedDraft(for: target)
            inlineFieldFocused = true
        }
    }

    private func seedDraft(for target: ResultsInlineEdit) {
        switch target {
        case .title(let id):
            editDraft = displayedNotes.first(where: { $0.id == id })?.note.title ?? ""
        case .tags(let id):
            editDraft = displayedNotes.first(where: { $0.id == id })?.tagsDisplay ?? ""
        }
    }

    private func commitInlineEdit() {
        guard let target = inlineEdit else { return }
        // Clear first so focus-loss does not re-enter commit.
        inlineEdit = nil
        inlineFieldFocused = false
        switch target {
        case .title(let id):
            onCommitTitle(id, editDraft)
        case .tags(let id):
            onCommitTags(id, editDraft)
        }
    }

    private func cancelInlineEdit() {
        inlineEdit = nil
        inlineFieldFocused = false
    }

    private func index(of ranked: RankedNote) -> Int? {
        displayedNotes.firstIndex(where: { $0.id == ranked.id })
    }

    private func handleKey(_ keyPress: KeyPress) -> KeyPress.Result {
        if keyPress.key == .escape {
            onClearSearch()
            return .handled
        }
        if keyPress.key == .upArrow {
            onMoveHighlight(-1)
            return .handled
        }
        if keyPress.key == .downArrow {
            onMoveHighlight(1)
            return .handled
        }
        if keyPress.modifiers.contains(.command) {
            let c = String(keyPress.characters).lowercased()
            if c == "j" {
                onMoveHighlight(1)
                return .handled
            }
            if c == "k" {
                onMoveHighlight(-1)
                return .handled
            }
        }
        if keyPress.modifiers.contains(.control) {
            let c = String(keyPress.characters).lowercased()
            if c == "n" || c == "j" {
                onMoveHighlight(1)
                return .handled
            }
            if c == "p" || c == "k" {
                onMoveHighlight(-1)
                return .handled
            }
        }
        if keyPress.key == .return {
            onActivateSearch()
            return .handled
        }
        return .ignored
    }

    private func reconcileHighlight(keeping preferredID: URL?) {
        let navigable = FuzzySearch.navigableIndices(in: displayedNotes, query: rankingQuery)
        guard !navigable.isEmpty else {
            highlightedIndex = 0
            return
        }

        let previousID = displayedNotes.indices.contains(highlightedIndex)
            ? displayedNotes[highlightedIndex].note.fileURL
            : nil

        if let preferredID,
           let idx = displayedNotes.firstIndex(where: { $0.note.fileURL == preferredID }),
           navigable.contains(idx) {
            highlightedIndex = idx
        } else if navigable.contains(highlightedIndex) {
            // Keep current highlight.
        } else {
            highlightedIndex = navigable[0]
        }

        let newID = displayedNotes[highlightedIndex].note.fileURL
        if newID != previousID || newID != preferredID {
            onHighlightIndex(highlightedIndex)
        }
    }
}
