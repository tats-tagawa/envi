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
