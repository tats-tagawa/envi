import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class KeyboardShortcutStore {
    static let storageKey = "appShortcutBindings"

    /// Revision so menus can rebuild when bindings change.
    private(set) var revision = 0

    private var bindings: [AppShortcutID: AppShortcutBinding] = [:]

    init() {
        bindings = Self.load()
    }

    func binding(for id: AppShortcutID) -> AppShortcutBinding {
        bindings[id] ?? id.defaultBinding
    }

    func setBinding(_ binding: AppShortcutBinding, for id: AppShortcutID) {
        bindings[id] = binding
        // Last write wins: clear any other override that now collides.
        // If another action's default equals this chord, leave a conflict warning in the UI.
        for other in AppShortcutID.allCases where other != id {
            if let custom = bindings[other], custom == binding {
                bindings.removeValue(forKey: other)
            }
        }
        persist()
        revision += 1
    }

    func reset(_ id: AppShortcutID) {
        bindings.removeValue(forKey: id)
        persist()
        revision += 1
    }

    func resetAll() {
        bindings = [:]
        persist()
        revision += 1
    }

    func isCustom(_ id: AppShortcutID) -> Bool {
        bindings[id] != nil && bindings[id] != id.defaultBinding
    }

    /// Other actions that currently resolve to the same chord.
    func conflicts(for id: AppShortcutID) -> [AppShortcutID] {
        let mine = binding(for: id)
        return AppShortcutID.allCases.filter { $0 != id && binding(for: $0) == mine }
    }

    func keyboardShortcut(for id: AppShortcutID) -> KeyboardShortcut {
        let b = binding(for: id)
        return KeyboardShortcut(b.keyEquivalent, modifiers: b.eventModifiers)
    }

    private func persist() {
        let payload = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private static func load() -> [AppShortcutID: AppShortcutBinding] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let raw = try? JSONDecoder().decode([String: AppShortcutBinding].self, from: data)
        else { return [:] }
        var result: [AppShortcutID: AppShortcutBinding] = [:]
        for (key, value) in raw {
            if let id = AppShortcutID(rawValue: key) {
                result[id] = value
            }
        }
        return result
    }
}

private struct KeyboardShortcutStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = KeyboardShortcutStore()
}

extension EnvironmentValues {
    @MainActor
    var shortcutStore: KeyboardShortcutStore {
        get { self[KeyboardShortcutStoreKey.self] }
        set { self[KeyboardShortcutStoreKey.self] = newValue }
    }
}
