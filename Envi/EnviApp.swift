import AppKit
import SwiftUI

@main
struct EnviApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = NotesFolderStore()
    @State private var themeStore = ThemeStore()
    @State private var shortcutStore = KeyboardShortcutStore()

    var body: some Scene {
        // Read observable fields so menus/tint refresh without destroying the view tree.
        let _ = shortcutStore.revision
        let _ = themeStore.systemAppearanceRevision

        WindowGroup {
            ContentView(store: store)
                .environment(\.themeStore, themeStore)
                .environment(\.shortcutStore, shortcutStore)
                .preferredColorScheme(themeStore.preferredColorScheme)
                .tint(themeStore.resolvedColors.accent.color)
                .onAppear {
                    themeStore.applyAppKitAppearance()
                }
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Notes Folder…") {
                    store.chooseFolder()
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .openNotesFolder))
            }

            CommandMenu("Note") {
                Button("Focus Search") {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .focusSearch))

                Button("Deselect Note") {
                    NotificationCenter.default.post(name: .deselectRestoreSearch, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .deselectNote))

                Button("Rename Note") {
                    NotificationCenter.default.post(name: .renameSelectedNote, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .renameNote))

                Button("Tag Note") {
                    NotificationCenter.default.post(name: .editTags, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .tagNote))

                Button("Delete Note") {
                    NotificationCenter.default.post(name: .deleteSelectedNote, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .deleteNote))

                Divider()

                Button("Toggle Task") {
                    NotificationCenter.default.post(name: .toggleTaskAtCursor, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .toggleTask))

                Button("Insert Task") {
                    NotificationCenter.default.post(name: .insertTaskAtCursor, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .insertTask))

                Button("Set Task Priority 1") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [TaskPriorityUserInfo.key: 1]
                    )
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .setTaskPriority1))

                Button("Set Task Priority 2") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [TaskPriorityUserInfo.key: 2]
                    )
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .setTaskPriority2))

                Button("Set Task Priority 3") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [TaskPriorityUserInfo.key: 3]
                    )
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .setTaskPriority3))

                Button("Clear Task Priority") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [:]
                    )
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .clearTaskPriority))

                Button("Set Task Deadline…") {
                    NotificationCenter.default.post(name: .requestTaskDeadlineSheet, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .setTaskDeadline))

                Button("Next Note") {
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: 1))
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .nextNote))

                Button("Previous Note") {
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: -1))
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .previousNote))
            }

            CommandMenu("View") {
                Button("Toggle Task Mode") {
                    NotificationCenter.default.post(name: .toggleTaskMode, object: nil)
                }
                .keyboardShortcut(shortcutStore.keyboardShortcut(for: .toggleTaskMode))
            }
        }

        Settings {
            SettingsView()
                .environment(\.themeStore, themeStore)
                .environment(\.shortcutStore, shortcutStore)
                .preferredColorScheme(themeStore.preferredColorScheme)
                .tint(themeStore.resolvedColors.accent.color)
        }
    }
}
