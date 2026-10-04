import SwiftUI

struct SidebarView: View {
    let displayedNotes: [RankedNote]
    @Binding var searchText: String
    @Binding var highlightedIndex: Int
    @Binding var sortOrder: [KeyPathComparator<RankedNote>]
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
    var onBeginRename: (Int) -> Void
    var onBeginEditTags: (Int) -> Void
    var onBeginDelete: (Int) -> Void

    /// Which column the last click landed in — used so row double-click can rename vs edit tags.
    @State private var lastClickedColumn: ListColumn = .title
    @AppStorage(ModifiedDateOrder.storageKey) private var dateOrder = ModifiedDateOrder.yearMonthDay.rawValue
    @AppStorage(ModifiedDateFormat.use24HourKey) private var use24Hour = false

    private enum ListColumn {
        case title
        case tags
        case other
    }

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
                    Text(ranked.note.title)
                        .font(.body.weight(ranked.note.fileURL == selectedNoteID ? .semibold : .regular))
                        .foregroundStyle(ranked.matchesQuery ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded {
                            lastClickedColumn = .title
                        })
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
                        .simultaneousGesture(TapGesture().onEnded {
                            lastClickedColumn = .other
                        })
                }
                .width(min: 120, ideal: 160)

                TableColumn("Tags", value: \.tagsDisplay) { ranked in
                    Text(ranked.tagsDisplay.isEmpty ? " " : ranked.tagsDisplay)
                        .foregroundStyle(ranked.matchesQuery ? Color.secondary : Color.secondary.opacity(0.55))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .simultaneousGesture(TapGesture().onEnded {
                            lastClickedColumn = .tags
                        })
                }
                .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: RankedNote.ID.self) { ids in
                if let id = ids.first,
                   let index = displayedNotes.firstIndex(where: { $0.id == id }) {
                    Button("Rename") { onBeginRename(index) }
                    Button("Edit Tags…") { onBeginEditTags(index) }
                    Divider()
                    Button("Move to Trash", role: .destructive) { onBeginDelete(index) }
                }
            } primaryAction: { ids in
                guard let id = ids.first,
                      let index = displayedNotes.firstIndex(where: { $0.id == id }) else { return }
                switch lastClickedColumn {
                case .tags:
                    onBeginEditTags(index)
                case .title, .other:
                    onBeginRename(index)
                }
            }
            .onChange(of: displayedNotes.count) { _, _ in
                reconcileHighlight(keeping: selectedNoteID)
            }
            .onChange(of: sortOrder) { _, _ in
                reconcileHighlight(keeping: selectedNoteID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
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
