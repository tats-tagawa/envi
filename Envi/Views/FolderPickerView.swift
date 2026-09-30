import SwiftUI

struct FolderPickerView: View {
    @Bindable var store: NotesFolderStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Choose Notes Folder")
                .font(.title2.weight(.semibold))

            Text("envi stores each note as a Markdown file. Pick a folder you can also open in other apps.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                Button("Use Documents/envi") {
                    store.useDefaultDocumentsFolder()
                }
                .keyboardShortcut(.defaultAction)

                Button("Choose Folder…") {
                    store.chooseFolder()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}
