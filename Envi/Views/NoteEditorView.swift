import SwiftUI

struct NoteEditorView: View {
    @Bindable var store: NotesFolderStore
    let note: Note?
    var editorFocus: FocusState<EditorFocusTarget?>.Binding
    var vimEnabled: Bool
    @Binding var vimMode: VimMode
    var onRenameOutcome: (NoteRenameOutcome) -> Void = { _ in }

    @State private var titleText = ""
    @State private var bodyText = ""
    /// Tracks which note the local buffers belong to (avoids cross-note bleed).
    @State private var editingNoteID: URL?

    var body: some View {
        Group {
            if let note {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $titleText)
                        .textFieldStyle(.plain)
                        .font(.headline)
                        .focused(editorFocus, equals: .title)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)
                        .onSubmit {
                            commitTitle(for: note.fileURL)
                            focusBodyAtEnd()
                        }

                    Divider()

                    NoteBodyTextView(
                        noteID: note.fileURL,
                        text: $bodyText,
                        isFocused: editorFocus.wrappedValue == .body,
                        vimEnabled: vimEnabled,
                        vimMode: $vimMode,
                        onBecameFirstResponder: {
                            if editorFocus.wrappedValue != .body {
                                editorFocus.wrappedValue = .body
                            }
                        },
                        onTextChange: { newValue in
                            guard editingNoteID == note.fileURL else { return }
                            store.updateBody(newValue, for: note.fileURL)
                        }
                    )
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: editorFocus.wrappedValue) { oldValue, newValue in
                    if oldValue == .title, newValue != .title {
                        commitTitle(for: note.fileURL)
                    }
                }
                .onDisappear {
                    if let id = editingNoteID {
                        commitTitle(for: id)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "doc.text",
                    description: Text("Search or create a note from the sidebar.")
                )
            }
        }
        .onChange(of: note?.fileURL) { _, newID in
            if let previous = editingNoteID, previous != newID {
                commitTitle(for: previous)
            }
            syncFromNote()
        }
        .onAppear {
            syncFromNote()
        }
        .onChange(of: note?.body) { _, newBody in
            guard let newBody, let note, editingNoteID == note.fileURL else { return }
            if bodyText != newBody {
                bodyText = newBody
            }
        }
        .onChange(of: note?.title) { _, newTitle in
            guard let newTitle, let note, editingNoteID == note.fileURL else { return }
            if titleText != newTitle {
                titleText = newTitle
            }
        }
    }

    private func focusBodyAtEnd() {
        editorFocus.wrappedValue = .body
        NotificationCenter.default.post(name: .focusNoteBodyAtEnd, object: nil)
    }

    private func syncFromNote() {
        guard let note else {
            titleText = ""
            bodyText = ""
            editingNoteID = nil
            return
        }
        editingNoteID = note.fileURL
        titleText = note.title
        bodyText = note.body
    }

    private func commitTitle(for noteID: URL) {
        let trimmed = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let outcome = store.updateTitle(trimmed, for: noteID)
        onRenameOutcome(outcome)
        if let selected = store.selectedNote {
            editingNoteID = selected.fileURL
            titleText = selected.title
        }
    }
}
