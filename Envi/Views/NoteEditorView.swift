import SwiftUI

struct NoteEditorView: View {
    @Bindable var store: NotesFolderStore
    let note: Note?
    var editorFocus: FocusState<EditorFocusTarget?>.Binding
    var vimEnabled: Bool
    @Binding var vimMode: VimMode

    @State private var bodyText = ""
    /// Tracks which note the local buffer belongs to (avoids cross-note bleed).
    @State private var editingNoteID: URL?

    var body: some View {
        Group {
            if let note {
                NoteBodyTextView(
                    noteID: note.fileURL,
                    text: $bodyText,
                    isFocused: editorFocus.wrappedValue == .body,
                    vimEnabled: vimEnabled,
                    preserveCaretForURL: nil,
                    onConsumedCaretPreserve: {},
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
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No Note Selected",
                    systemImage: "doc.text",
                    description: Text("Search or create a note from the list.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
        .onChange(of: note?.fileURL) { _, _ in
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
    }

    private func syncFromNote() {
        guard let note else {
            bodyText = ""
            editingNoteID = nil
            return
        }
        editingNoteID = note.fileURL
        bodyText = note.body
    }
}
