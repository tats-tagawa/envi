import SwiftUI

struct NoteEditorView: View {
    @Bindable var store: NotesFolderStore
    let note: Note?
    var editorFocus: FocusState<EditorFocusTarget?>.Binding

    @State private var titleText = ""
    @State private var bodyText = ""
    /// Tracks which note the local title/body buffers belong to (avoids cross-note bleed).
    @State private var editingNoteID: URL?

    var body: some View {
        Group {
            if let note {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $titleText)
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                        .focused(editorFocus, equals: .title)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .onSubmit {
                            commitTitle(for: note.fileURL)
                            focusBodyAtEnd()
                        }

                    Divider()

                    NoteBodyTextView(
                        text: $bodyText,
                        isFocused: editorFocus.wrappedValue == .body,
                        onBecameFirstResponder: {
                            if editorFocus.wrappedValue != .body {
                                editorFocus.wrappedValue = .body
                            }
                        },
                        onTextChange: { newValue in
                            // Ignore updates that arrive after we already switched notes.
                            guard editingNoteID == note.fileURL else { return }
                            store.updateBody(newValue, for: note.fileURL)
                        }
                    )
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onChange(of: editorFocus.wrappedValue) { oldValue, newValue in
                    // Rename when leaving the title field (e.g. click into the body).
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
        guard !trimmed.isEmpty else { return }
        store.updateTitle(trimmed, for: noteID)
        // After a rename the file URL changes; keep local state aligned.
        if let selected = store.selectedNote {
            editingNoteID = selected.fileURL
            titleText = selected.title
        }
    }
}
