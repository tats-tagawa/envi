import SwiftUI

@main
struct EnviApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = NotesFolderStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Notes Folder…") {
                    store.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandMenu("Note") {
                Button("Focus Search") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)

                Button("Deselect Note") {
                    NotificationCenter.default.post(name: .deselectRestoreSearch, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Button("Rename Note") {
                    NotificationCenter.default.post(name: .renameSelectedNote, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Tag Note") {
                    NotificationCenter.default.post(name: .editTags, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])

                Divider()

                Button("Next Note") {
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: 1))
                }
                .keyboardShortcut("j", modifiers: .command)

                Button("Previous Note") {
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: -1))
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
