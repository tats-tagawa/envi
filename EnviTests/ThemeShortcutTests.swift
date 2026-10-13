import XCTest
@testable import Envi

final class ThemeShortcutTests: XCTestCase {
    func testEveryPresetProvidesColors() {
        for preset in ThemePreset.allCases where preset != .system {
            let colors = preset.colors()
            XCTAssertEqual(colors.textPrimary.opacity, 1, accuracy: 0.001, "\(preset.title)")
        }
    }

    func testSystemResolvesToDefaultLightOrDark() {
        let system = ThemePreset.system.colors()
        let light = ThemePreset.defaultLight.colors()
        let dark = ThemePreset.defaultDark.colors()
        XCTAssertTrue(
            system == light || system == dark,
            "System should match Default Light or Default Dark"
        )
    }

    func testOverrideMerge() {
        var base = ThemePreset.monokai.colors()
        let override = CodableColor(hex: "FF0000")
        let merged = base.merging(overrides: [.accent: override])
        XCTAssertEqual(merged.accent, override)
        XCTAssertEqual(merged.editorBackground, base.editorBackground)
    }

    func testHexEightDigitOpacity() {
        let color = CodableColor(hex: "007AFF33")
        XCTAssertEqual(color.red, 0, accuracy: 0.01)
        XCTAssertEqual(color.green, 122.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(color.blue, 255.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(color.opacity, 51.0 / 255.0, accuracy: 0.01)
    }

    func testShortcutCatalogHasDefaults() {
        for id in AppShortcutID.allCases {
            let binding = id.defaultBinding
            XCTAssertFalse(binding.key.isEmpty, id.title)
        }
        XCTAssertEqual(AppShortcutID.settingsOrdered.count, AppShortcutID.allCases.count)
    }

    func testShortcutBindingEncodeRoundTrip() throws {
        let original = AppShortcutBinding.mods("l", .command)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppShortcutBinding.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.displayString, "⌘L")
    }

    @MainActor
    func testShortcutStoreConflictDetection() {
        let store = KeyboardShortcutStore()
        store.resetAll()
        let chord = AppShortcutBinding.mods("l", .command)
        store.setBinding(chord, for: .renameNote)
        // focusSearch default is also ⌘L
        let conflicts = store.conflicts(for: .renameNote)
        XCTAssertTrue(conflicts.contains(.focusSearch))
    }
}
