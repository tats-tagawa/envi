import AppKit
import SwiftUI

@main
struct EnviApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = NotesFolderStore()
    @AppStorage(AppearanceMode.storageKey) private var appearanceMode = AppearanceMode.system.rawValue
    /// Bumped when macOS Light/Dark changes so System mode re-resolves.
    @State private var systemAppearanceRevision = 0
    @State private var isObservingSystemTheme = false

    private var resolvedAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(resolvedAppearance.colorScheme)
                // Force a clean rebuild when switching System/Light/Dark (and when the OS theme flips).
                .id("\(appearanceMode)-\(systemAppearanceRevision)")
                .onAppear {
                    applyAppAppearance()
                    startObservingSystemThemeIfNeeded()
                }
                .onChange(of: appearanceMode) { _, _ in
                    applyAppAppearance()
                }
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

                Button("Delete Note") {
                    NotificationCenter.default.post(name: .deleteSelectedNote, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)

                Divider()

                Button("Toggle Task") {
                    NotificationCenter.default.post(name: .toggleTaskAtCursor, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Insert Task") {
                    NotificationCenter.default.post(name: .insertTaskAtCursor, object: nil)
                }
                .keyboardShortcut(.return, modifiers: [.command, .shift])

                Button("Set Task Priority 1") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [TaskPriorityUserInfo.key: 1]
                    )
                }
                .keyboardShortcut("1", modifiers: [.control, .command])

                Button("Set Task Priority 2") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [TaskPriorityUserInfo.key: 2]
                    )
                }
                .keyboardShortcut("2", modifiers: [.control, .command])

                Button("Set Task Priority 3") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [TaskPriorityUserInfo.key: 3]
                    )
                }
                .keyboardShortcut("3", modifiers: [.control, .command])

                Button("Clear Task Priority") {
                    NotificationCenter.default.post(
                        name: .setTaskPriorityAtCursor,
                        object: nil,
                        userInfo: [:]
                    )
                }
                .keyboardShortcut("0", modifiers: [.control, .command])

                Button("Set Task Deadline…") {
                    NotificationCenter.default.post(name: .requestTaskDeadlineSheet, object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Next Note") {
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: 1))
                }
                .keyboardShortcut("j", modifiers: .command)

                Button("Previous Note") {
                    NotificationCenter.default.post(NoteHighlightDelta.notification(delta: -1))
                }
                .keyboardShortcut("k", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Toggle Task Mode") {
                    NotificationCenter.default.post(name: .toggleTaskMode, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.control, .command])
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(resolvedAppearance.colorScheme)
                .id("settings-\(appearanceMode)-\(systemAppearanceRevision)")
        }
    }

    private func applyAppAppearance() {
        let appearance = resolvedAppearance.nsAppearance
        NSApp.appearance = appearance
        // Clear any window-level override left over from a previous Light/Dark choice.
        for window in NSApp.windows {
            window.appearance = appearance
        }
    }

    private func startObservingSystemThemeIfNeeded() {
        guard !isObservingSystemTheme else { return }
        isObservingSystemTheme = true

        DistributedNotificationCenter.default.addObserver(
            forName: AppearanceMode.systemThemeChanged,
            object: nil,
            queue: .main
        ) { _ in
            let mode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: AppearanceMode.storageKey) ?? "")
                ?? .system
            guard mode == .system else { return }
            NSApp.appearance = nil
            for window in NSApp.windows {
                window.appearance = nil
            }
            systemAppearanceRevision += 1
        }
    }
}
