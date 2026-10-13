import AppKit
import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class ThemeStore {
    static let overridesKey = "themeColorOverrides"

    var presetRaw: String {
        didSet {
            UserDefaults.standard.set(presetRaw, forKey: ThemePreset.storageKey)
            if oldValue != presetRaw {
                overrides = [:]
                persistOverrides()
            }
            applyAppKitAppearance()
        }
    }

    /// Token overrides on top of the current preset.
    private(set) var overrides: [AppThemeColors.Token: CodableColor] = [:]

    /// Bumped when macOS Light/Dark changes so System preset re-resolves.
    var systemAppearanceRevision = 0

    var preset: ThemePreset {
        get { ThemePreset(rawValue: presetRaw) ?? .system }
        set { presetRaw = newValue.rawValue }
    }

    var resolvedColors: AppThemeColors {
        _ = systemAppearanceRevision
        return preset.colors().merging(overrides: overrides)
    }

    var preferredColorScheme: ColorScheme {
        _ = systemAppearanceRevision
        return preset.preferredColorScheme
    }

    var hasOverrides: Bool { !overrides.isEmpty }

    init() {
        presetRaw = UserDefaults.standard.string(forKey: ThemePreset.storageKey) ?? ThemePreset.system.rawValue
        overrides = Self.loadOverrides()
        applyAppKitAppearance()
        startObservingSystemTheme()
    }

    func setColor(_ color: Color, for token: AppThemeColors.Token) {
        overrides[token] = CodableColor(color)
        persistOverrides()
    }

    func resetOverrides() {
        overrides = [:]
        persistOverrides()
    }

    func colorBinding(for token: AppThemeColors.Token) -> Binding<Color> {
        Binding(
            get: { self.resolvedColors[token].color },
            set: { self.setColor($0, for: token) }
        )
    }

    func applyAppKitAppearance() {
        let appearance = preset.nsAppearance
        // Prefer shared over NSApp (IUO) so early launch / unit tests don't crash.
        let app = NSApplication.shared
        app.appearance = appearance
        for window in app.windows {
            window.appearance = appearance
        }
    }

    private func persistOverrides() {
        let payload = Dictionary(uniqueKeysWithValues: overrides.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: Self.overridesKey)
        }
    }

    private static func loadOverrides() -> [AppThemeColors.Token: CodableColor] {
        guard let data = UserDefaults.standard.data(forKey: overridesKey),
              let raw = try? JSONDecoder().decode([String: CodableColor].self, from: data)
        else { return [:] }
        var result: [AppThemeColors.Token: CodableColor] = [:]
        for (key, value) in raw {
            if let token = AppThemeColors.Token(rawValue: key) {
                result[token] = value
            }
        }
        return result
    }

    private func startObservingSystemTheme() {
        DistributedNotificationCenter.default.addObserver(
            forName: AppearanceMode.systemThemeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.preset == .system else { return }
                self.applyAppKitAppearance()
                self.systemAppearanceRevision += 1
            }
        }
    }
}

private struct ThemeStoreKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ThemeStore()
}

extension EnvironmentValues {
    @MainActor
    var themeStore: ThemeStore {
        get { self[ThemeStoreKey.self] }
        set { self[ThemeStoreKey.self] = newValue }
    }
}
