import AppKit
import SwiftUI

/// Which results-list cell is being edited inline.
enum ResultsInlineEdit: Equatable {
    case title(URL)
    case tags(URL)
}

struct SidebarView: View {
    var isTaskMode: Bool
    let displayedNotes: [RankedNote]
    let displayedTasks: [RankedTask]
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
    var onToggleTask: (RankedTask) -> Void
    /// False while ContentView is writing the search field itself (⌘D, selection title).
    var reconcileSearchChanges: Bool = true
    /// Stronger selected-row emphasis while the search/list is key; quieter while writing.
    var emphasizeSelection: Bool = true

    @Environment(\.themeStore) private var themeStore
    @Environment(\.shortcutStore) private var shortcutStore
    @State private var editDraft = ""
    @FocusState private var inlineFieldFocused: Bool
    @AppStorage(ModifiedDateOrder.storageKey) private var dateOrder = ModifiedDateOrder.monthDayYear.rawValue
    @AppStorage(ModifiedDateFormat.use24HourKey) private var use24Hour = false

    private var theme: AppThemeColors { themeStore.resolvedColors }

    private var resolvedDateOrder: ModifiedDateOrder {
        ModifiedDateOrder(rawValue: dateOrder) ?? .monthDayYear
    }

    /// Hide Tags until a note has tags, or while editing tags (⌘⇧T).
    private var showsTagsColumn: Bool {
        if case .tags = inlineEdit { return true }
        return displayedNotes.contains { !$0.tagsDisplay.isEmpty }
    }

    private var searchPlaceholder: String {
        isTaskMode ? "Search or create task…" : "Search or create…"
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

    private var taskTableSelection: Binding<Set<RankedTask.ID>> {
        Binding(
            get: {
                guard let selectedNoteID,
                      displayedTasks.indices.contains(highlightedIndex),
                      displayedTasks[highlightedIndex].task.noteURL == selectedNoteID else {
                    return []
                }
                return [displayedTasks[highlightedIndex].id]
            },
            set: { newValue in
                guard let id = newValue.first,
                      let index = displayedTasks.firstIndex(where: { $0.id == id }) else { return }
                onSelectIndex(index)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(theme.textPrimary.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(theme.searchFieldBackground.color)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(theme.separator.color, lineWidth: 1)
                )
                .focused(editorFocus, equals: .search)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .onKeyPress { keyPress in
                    handleKey(keyPress)
                }
                .onChange(of: searchText) { _, _ in
                    onSearchEdited()
                    if reconcileSearchChanges {
                        reconcileHighlight(keeping: selectedNoteID)
                    }
                }

            ZStack {
                if isTaskMode {
                    tasksTable
                        .enviThemedTable(theme: theme)
                        .id("tasks-table")
                } else {
                    notesTable
                        .enviThemedTable(theme: theme)
                        // Rebuild when column count changes — in-place column swaps can assert in AppKit.
                        .id("notes-table-\(showsTagsColumn)")
                        .contextMenu(forSelectionType: RankedNote.ID.self) { ids in
                            if let id = ids.first,
                               let index = displayedNotes.firstIndex(where: { $0.id == id }) {
                                Button("Rename") { beginInlineEdit(.title(id), at: index) }
                                Button("Edit Tags…") { beginInlineEdit(.tags(id), at: index) }
                                Divider()
                                Button("Move to Trash", role: .destructive) { onBeginDelete(index) }
                            }
                        }
                }

                if isTaskMode ? displayedTasks.isEmpty : displayedNotes.isEmpty {
                    Text(isTaskMode ? "Type to search or create a task" : "Type to search or create")
                        .font(.callout)
                        .foregroundStyle(theme.textSecondary.color)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: displayedNotes.count) { _, _ in
                guard !isTaskMode else { return }
                reconcileHighlight(keeping: selectedNoteID)
            }
            .onChange(of: displayedTasks.count) { _, _ in
                guard isTaskMode else { return }
                reconcileHighlight(keeping: selectedNoteID)
            }
            .onChange(of: isTaskMode) { _, _ in
                reconcileHighlight(keeping: selectedNoteID)
            }
            .onChange(of: sortOrder) { _, _ in
                guard !isTaskMode else { return }
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
        .background(theme.sidebarBackground.color)
    }

    @ViewBuilder
    private var notesTable: some View {
        if showsTagsColumn {
            Table(displayedNotes, selection: tableSelection, sortOrder: $sortOrder) {
                TableColumn("Title", value: \.note.title) { ranked in
                    titleCell(for: ranked)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Date Modified", value: \.note.updatedAt) { ranked in
                    dateCell(for: ranked)
                }
                .width(min: 100, ideal: 130)

                TableColumn("Tags", value: \.tagsDisplay) { ranked in
                    tagsCell(for: ranked)
                }
                .width(min: 60, ideal: 100)
            }
        } else {
            Table(displayedNotes, selection: tableSelection, sortOrder: $sortOrder) {
                TableColumn("Title", value: \.note.title) { ranked in
                    titleCell(for: ranked)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Date Modified", value: \.note.updatedAt) { ranked in
                    dateCell(for: ranked)
                }
                .width(min: 100, ideal: 130)
            }
        }
    }

    private var tasksTable: some View {
        Table(displayedTasks, selection: taskTableSelection) {
            TableColumn("Task") { ranked in
                taskCell(for: ranked)
            }
            .width(min: 140, ideal: 220)

            TableColumn("P") { ranked in
                Text(ranked.task.priority.map { "P\($0)" } ?? " ")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(ranked.matchesQuery ? theme.textSecondary.color : theme.textDimmed.color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .width(min: 28, ideal: 36)

            TableColumn("Due") { ranked in
                dueCell(for: ranked)
            }
            .width(min: 64, ideal: 80)

            TableColumn("Note") { ranked in
                Text(ranked.task.noteTitle)
                    .font(.callout)
                    .foregroundStyle(ranked.matchesQuery ? theme.textSecondary.color : theme.textDimmed.color)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .width(min: 80, ideal: 120)
        }
    }

    private func dueCell(for ranked: RankedTask) -> some View {
        let label: String
        let overdue: Bool
        if let deadline = ranked.task.deadline {
            label = Self.dueFormatter.string(from: deadline)
            let startToday = Calendar.current.startOfDay(for: Date())
            overdue = !ranked.task.isDone && deadline < startToday
        } else {
            label = " "
            overdue = false
        }
        return Text(label)
            .font(.callout)
            .foregroundStyle(
                overdue
                    ? theme.danger.color.opacity(ranked.matchesQuery ? 1 : 0.7)
                    : (ranked.matchesQuery ? theme.textSecondary.color : theme.textDimmed.color)
            )
            .lineLimit(1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private static let dueFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f
    }()

    private func taskCell(for ranked: RankedTask) -> some View {
        let isSelected = ranked.task.noteURL == selectedNoteID
            && displayedTasks.indices.contains(highlightedIndex)
            && displayedTasks[highlightedIndex].id == ranked.id
        return HStack(spacing: 8) {
            Button {
                onToggleTask(ranked)
            } label: {
                Image(systemName: ranked.task.isDone ? "checkmark.square.fill" : "square")
                    .foregroundStyle(ranked.task.isDone ? theme.checkboxOn.color : theme.textSecondary.color)
            }
            .buttonStyle(.plain)
            .help(ranked.task.isDone ? "Mark as not done" : "Mark as done")

            Text(ranked.task.text.isEmpty ? "Untitled" : ranked.task.text)
                .font(.callout.weight(isSelected && emphasizeSelection ? .semibold : .regular))
                .strikethrough(ranked.task.isDone, color: theme.textSecondary.color)
                .foregroundStyle(
                    ranked.matchesQuery
                        ? theme.textPrimary.color.opacity(isSelected && emphasizeSelection ? 1 : 0.9)
                        : theme.textDimmed.color
                )
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func dateCell(for ranked: RankedNote) -> some View {
        let label = ModifiedDateFormat.string(
            for: ranked.note.updatedAt,
            order: resolvedDateOrder,
            use24Hour: use24Hour
        )
        let tip = ModifiedDateFormat.tooltip(
            for: ranked.note.updatedAt,
            order: resolvedDateOrder,
            use24Hour: use24Hour
        )
        return Text(label)
            .font(.callout)
            .foregroundStyle(ranked.matchesQuery ? theme.textSecondary.color : theme.textDimmed.color)
            .lineLimit(1)
            .help(tip)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private func titleCell(for ranked: RankedNote) -> some View {
        if case .title(let id) = inlineEdit, id == ranked.id {
            inlineEditor(placeholder: "Title")
        } else {
            let isSelected = ranked.note.fileURL == selectedNoteID
            Text(ranked.note.title)
                .font(.callout.weight(isSelected && emphasizeSelection ? .semibold : .regular))
                .foregroundStyle(
                    ranked.matchesQuery
                        ? theme.textPrimary.color.opacity(isSelected && emphasizeSelection ? 1 : 0.9)
                        : theme.textDimmed.color
                )
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
                .font(.callout)
                .foregroundStyle(ranked.matchesQuery ? theme.textSecondary.color : theme.textDimmed.color)
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
        if let current = inlineEdit, current != target {
            commitInlineEdit()
        }
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
        let binding = { (id: AppShortcutID) in shortcutStore.binding(for: id) }
        if AppShortcutBinding.matches(binding(.searchClear), keyPress: keyPress) {
            onClearSearch()
            return .handled
        }
        if AppShortcutBinding.matches(binding(.searchMoveUp), keyPress: keyPress)
            || AppShortcutBinding.matches(binding(.searchCtrlK), keyPress: keyPress)
            || AppShortcutBinding.matches(binding(.searchCtrlP), keyPress: keyPress)
            || AppShortcutBinding.matches(binding(.previousNote), keyPress: keyPress) {
            onMoveHighlight(-1)
            return .handled
        }
        if AppShortcutBinding.matches(binding(.searchMoveDown), keyPress: keyPress)
            || AppShortcutBinding.matches(binding(.searchCtrlJ), keyPress: keyPress)
            || AppShortcutBinding.matches(binding(.searchCtrlN), keyPress: keyPress)
            || AppShortcutBinding.matches(binding(.nextNote), keyPress: keyPress) {
            onMoveHighlight(1)
            return .handled
        }
        if AppShortcutBinding.matches(binding(.searchActivate), keyPress: keyPress) {
            onActivateSearch()
            return .handled
        }
        return .ignored
    }

    private func reconcileHighlight(keeping preferredID: URL?) {
        if isTaskMode {
            reconcileTaskHighlight(keeping: preferredID)
        } else {
            reconcileNoteHighlight(keeping: preferredID)
        }
    }

    private func reconcileNoteHighlight(keeping preferredID: URL?) {
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
        // A cleared selection (⌘D) must not immediately reselect the highlighted row.
        guard let preferredID else { return }
        if newID != previousID || newID != preferredID {
            onHighlightIndex(highlightedIndex)
        }
    }

    private func reconcileTaskHighlight(keeping preferredID: URL?) {
        let navigable = FuzzySearch.navigableIndices(in: displayedTasks, query: rankingQuery)
        guard !navigable.isEmpty else {
            highlightedIndex = 0
            return
        }

        let previousID = displayedTasks.indices.contains(highlightedIndex)
            ? displayedTasks[highlightedIndex].task.noteURL
            : nil

        if let preferredID,
           let idx = displayedTasks.firstIndex(where: { $0.task.noteURL == preferredID }),
           navigable.contains(idx) {
            highlightedIndex = idx
        } else if navigable.contains(highlightedIndex) {
            // Keep current highlight.
        } else {
            highlightedIndex = navigable[0]
        }

        let newID = displayedTasks[highlightedIndex].task.noteURL
        guard let preferredID else { return }
        if newID != previousID || newID != preferredID {
            onHighlightIndex(highlightedIndex)
        }
    }
}

// MARK: - Table theming

private extension View {
    /// Hide system table fills so the sidebar theme shows through.
    /// Do not poke NSTableView/row views from layout — that races SwiftUI column updates and can assert.
    func enviThemedTable(theme: AppThemeColors) -> some View {
        self
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .alternatingRowBackgrounds(.disabled)
            .scrollContentBackground(.hidden)
            .background(theme.sidebarBackground.color)
    }
}
