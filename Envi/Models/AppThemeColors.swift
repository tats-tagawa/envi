import SwiftUI

/// Paintable tokens for Envi chrome.
struct AppThemeColors: Codable, Hashable, Sendable {
    var windowBackground: CodableColor
    var sidebarBackground: CodableColor
    var editorBackground: CodableColor
    var textPrimary: CodableColor
    var textSecondary: CodableColor
    var textDimmed: CodableColor
    var accent: CodableColor
    var selection: CodableColor
    var separator: CodableColor
    var searchFieldBackground: CodableColor
    var statusBarBackground: CodableColor
    var statusBarText: CodableColor
    var danger: CodableColor
    var checkboxOn: CodableColor

    enum Token: String, CaseIterable, Identifiable, Codable {
        case windowBackground
        case sidebarBackground
        case editorBackground
        case textPrimary
        case textSecondary
        case textDimmed
        case accent
        case selection
        case separator
        case searchFieldBackground
        case statusBarBackground
        case statusBarText
        case danger
        case checkboxOn

        var id: String { rawValue }

        var title: String {
            switch self {
            case .windowBackground: "Window Background"
            case .sidebarBackground: "Sidebar Background"
            case .editorBackground: "Editor Background"
            case .textPrimary: "Primary Text"
            case .textSecondary: "Secondary Text"
            case .textDimmed: "Dimmed Text"
            case .accent: "Accent"
            case .selection: "Selection"
            case .separator: "Separator"
            case .searchFieldBackground: "Search Field"
            case .statusBarBackground: "Status Bar Background"
            case .statusBarText: "Status Bar Text"
            case .danger: "Danger / Overdue"
            case .checkboxOn: "Checkbox On"
            }
        }
    }

    subscript(_ token: Token) -> CodableColor {
        get {
            switch token {
            case .windowBackground: windowBackground
            case .sidebarBackground: sidebarBackground
            case .editorBackground: editorBackground
            case .textPrimary: textPrimary
            case .textSecondary: textSecondary
            case .textDimmed: textDimmed
            case .accent: accent
            case .selection: selection
            case .separator: separator
            case .searchFieldBackground: searchFieldBackground
            case .statusBarBackground: statusBarBackground
            case .statusBarText: statusBarText
            case .danger: danger
            case .checkboxOn: checkboxOn
            }
        }
        set {
            switch token {
            case .windowBackground: windowBackground = newValue
            case .sidebarBackground: sidebarBackground = newValue
            case .editorBackground: editorBackground = newValue
            case .textPrimary: textPrimary = newValue
            case .textSecondary: textSecondary = newValue
            case .textDimmed: textDimmed = newValue
            case .accent: accent = newValue
            case .selection: selection = newValue
            case .separator: separator = newValue
            case .searchFieldBackground: searchFieldBackground = newValue
            case .statusBarBackground: statusBarBackground = newValue
            case .statusBarText: statusBarText = newValue
            case .danger: danger = newValue
            case .checkboxOn: checkboxOn = newValue
            }
        }
    }

    func merging(overrides: [Token: CodableColor]) -> AppThemeColors {
        var copy = self
        for (token, color) in overrides {
            copy[token] = color
        }
        return copy
    }

    /// Build a UI theme from a small set of palette roles.
    static func make(
        window: String,
        sidebar: String,
        editor: String,
        text: String,
        secondary: String,
        dimmed: String,
        accent: String,
        selection: String,
        separator: String,
        search: String,
        statusBar: String,
        statusText: String,
        danger: String,
        checkbox: String
    ) -> AppThemeColors {
        AppThemeColors(
            windowBackground: CodableColor(hex: window),
            sidebarBackground: CodableColor(hex: sidebar),
            editorBackground: CodableColor(hex: editor),
            textPrimary: CodableColor(hex: text),
            textSecondary: CodableColor(hex: secondary),
            textDimmed: CodableColor(hex: dimmed),
            accent: CodableColor(hex: accent),
            selection: CodableColor(hex: selection),
            separator: CodableColor(hex: separator),
            searchFieldBackground: CodableColor(hex: search),
            statusBarBackground: CodableColor(hex: statusBar),
            statusBarText: CodableColor(hex: statusText),
            danger: CodableColor(hex: danger),
            checkboxOn: CodableColor(hex: checkbox)
        )
    }
}
