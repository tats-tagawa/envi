import SwiftUI

struct NoteEditorView: View {
    @Bindable var store: NotesFolderStore
    let note: Note?

    @State private var titleText = ""
    @State private var bodyText = ""
    @State private var editingNoteID: URL?

    var body: some View {
        Group {
            if let note {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Title", text: $titleText)
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .onSubmit {
                            commitTitle(for: note.fileURL)
                        }

                    Divider()

                    TextEditor(text: $bodyText)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: bodyText) { _, newValue in
                            guard editingNoteID == note.fileURL else { return }
                            store.updateBody(newValue, for: note.fileURL)
                        }
                }
                .onChange(of: titleText) { _, _ in
                    // Title is committed on submit / blur via onSubmit; also sync when leaving note.
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
            // External reload: update editor if we aren't mid-edit debounce for same content source.
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
    }
}
