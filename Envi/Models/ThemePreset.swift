import SwiftUI

enum ThemePreset: String, CaseIterable, Identifiable, Codable {
    case system
    case defaultLight
    case defaultDark
    case catppuccinLatte
    case catppuccinMocha
    case monokai
    case gruvbox
    case solarizedLight
    case solarizedDark
    case tokyoNight
    case tokyoNightDay
    case nord
    case githubLight
    case githubDark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .defaultLight: "Default Light"
        case .defaultDark: "Default Dark"
        case .catppuccinLatte: "Catppuccin Latte"
        case .catppuccinMocha: "Catppuccin Mocha"
        case .monokai: "Monokai"
        case .gruvbox: "Gruvbox"
        case .solarizedLight: "Solarized Light"
        case .solarizedDark: "Solarized Dark"
        case .tokyoNight: "Tokyo Night"
        case .tokyoNightDay: "Tokyo Night Day"
        case .nord: "Nord"
        case .githubLight: "GitHub Light"
        case .githubDark: "GitHub Dark"
        }
    }

    /// Whether this preset prefers light or dark controls (System resolves at runtime).
    var isDark: Bool {
        switch self {
        case .system:
            return AppearanceMode.systemColorScheme == .dark
        case .defaultLight, .catppuccinLatte, .solarizedLight, .tokyoNightDay, .githubLight:
            return false
        case .defaultDark, .catppuccinMocha, .monokai, .gruvbox, .solarizedDark, .tokyoNight, .nord, .githubDark:
            return true
        }
    }

    var preferredColorScheme: ColorScheme {
        isDark ? .dark : .light
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        default: NSAppearance(named: isDark ? .darkAqua : .aqua)
        }
    }

    static let storageKey = "themePreset"

    /// Base colors for this preset (System uses Default Light/Dark).
    func colors() -> AppThemeColors {
        switch self {
        case .system:
            return (AppearanceMode.systemColorScheme == .dark ? ThemePreset.defaultDark : .defaultLight).colors()
        case .defaultLight:
            return .make(
                window: "F2F2F7",
                sidebar: "FFFFFF",
                editor: "FFFFFF",
                text: "1C1C1E",
                secondary: "6C6C70",
                dimmed: "AEAEB2",
                accent: "007AFF",
                selection: "007AFF33",
                separator: "C6C6C8",
                search: "E5E5EA",
                statusBar: "F2F2F7",
                statusText: "6C6C70",
                danger: "FF3B30",
                checkbox: "007AFF"
            )
        case .defaultDark:
            return .make(
                window: "1C1C1E",
                sidebar: "2C2C2E",
                editor: "1C1C1E",
                text: "F5F5F7",
                secondary: "98989D",
                dimmed: "636366",
                accent: "0A84FF",
                selection: "0A84FF44",
                separator: "38383A",
                search: "3A3A3C",
                statusBar: "1C1C1E",
                statusText: "98989D",
                danger: "FF453A",
                checkbox: "0A84FF"
            )
        case .catppuccinLatte:
            // Official Catppuccin Latte
            return .make(
                window: "E6E9EF", // mantle
                sidebar: "EFF1F5", // base
                editor: "EFF1F5",
                text: "4C4F69",
                secondary: "6C6F85",
                dimmed: "9CA0B0",
                accent: "1E66F5", // blue
                selection: "1E66F533",
                separator: "CCD0DA",
                search: "CCD0DA",
                statusBar: "E6E9EF",
                statusText: "6C6F85",
                danger: "D20F39",
                checkbox: "1E66F5"
            )
        case .catppuccinMocha:
            return .make(
                window: "181825", // mantle
                sidebar: "1E1E2E", // base
                editor: "1E1E2E",
                text: "CDD6F4",
                secondary: "A6ADC8",
                dimmed: "6C7086",
                accent: "89B4FA",
                selection: "89B4FA44",
                separator: "313244",
                search: "313244",
                statusBar: "181825",
                statusText: "A6ADC8",
                danger: "F38BA8",
                checkbox: "89B4FA"
            )
        case .monokai:
            return .make(
                window: "1E1F1C",
                sidebar: "272822",
                editor: "272822",
                text: "F8F8F2",
                secondary: "75715E",
                dimmed: "49483E",
                accent: "A6E22E",
                selection: "49483E",
                separator: "3E3D32",
                search: "3E3D32",
                statusBar: "1E1F1C",
                statusText: "75715E",
                danger: "F92672",
                checkbox: "A6E22E"
            )
        case .gruvbox:
            return .make(
                window: "1D2021",
                sidebar: "282828",
                editor: "282828",
                text: "EBDBB2",
                secondary: "A89984",
                dimmed: "928374",
                accent: "FABD2F",
                selection: "504945",
                separator: "3C3836",
                search: "3C3836",
                statusBar: "1D2021",
                statusText: "A89984",
                danger: "FB4934",
                checkbox: "FABD2F"
            )
        case .solarizedLight:
            return .make(
                window: "EEE8D5", // base2
                sidebar: "FDF6E3", // base3
                editor: "FDF6E3",
                text: "657B83", // base00
                secondary: "93A1A1",
                dimmed: "93A1A1",
                accent: "268BD2",
                selection: "EEE8D5",
                separator: "EEE8D5",
                search: "EEE8D5",
                statusBar: "EEE8D5",
                statusText: "657B83",
                danger: "DC322F",
                checkbox: "268BD2"
            )
        case .solarizedDark:
            return .make(
                window: "073642", // base02
                sidebar: "002B36", // base03
                editor: "002B36",
                text: "839496", // base0
                secondary: "586E75",
                dimmed: "586E75",
                accent: "268BD2",
                selection: "073642",
                separator: "073642",
                search: "073642",
                statusBar: "073642",
                statusText: "93A1A1",
                danger: "DC322F",
                checkbox: "2AA198"
            )
        case .tokyoNight:
            return .make(
                window: "16161E",
                sidebar: "1A1B26",
                editor: "1A1B26",
                text: "A9B1D6",
                secondary: "565F89",
                dimmed: "414868",
                accent: "7AA2F7",
                selection: "283457",
                separator: "292E42",
                search: "292E42",
                statusBar: "16161E",
                statusText: "565F89",
                danger: "F7768E",
                checkbox: "7AA2F7"
            )
        case .tokyoNightDay:
            return .make(
                window: "E1E2E7",
                sidebar: "E9E9ED",
                editor: "E9E9ED",
                text: "3760BF",
                secondary: "6172B0",
                dimmed: "848CB5",
                accent: "2E7DE9",
                selection: "C4CADF",
                separator: "C4CADF",
                search: "D0D5E3",
                statusBar: "E1E2E7",
                statusText: "6172B0",
                danger: "F52A65",
                checkbox: "2E7DE9"
            )
        case .nord:
            return .make(
                window: "3B4252", // nord1
                sidebar: "2E3440", // nord0
                editor: "2E3440",
                text: "ECEFF4", // nord6
                secondary: "D8DEE9", // nord4
                dimmed: "4C566A", // nord3
                accent: "88C0D0", // nord8
                selection: "434C5E",
                separator: "434C5E",
                search: "434C5E",
                statusBar: "3B4252",
                statusText: "D8DEE9",
                danger: "BF616A",
                checkbox: "88C0D0"
            )
        case .githubLight:
            return .make(
                window: "F6F8FA",
                sidebar: "FFFFFF",
                editor: "FFFFFF",
                text: "24292F",
                secondary: "57606A",
                dimmed: "8C959F",
                accent: "0969DA",
                selection: "0969DA33",
                separator: "D0D7DE",
                search: "F6F8FA",
                statusBar: "F6F8FA",
                statusText: "57606A",
                danger: "CF222E",
                checkbox: "0969DA"
            )
        case .githubDark:
            return .make(
                window: "010409",
                sidebar: "0D1117",
                editor: "0D1117",
                text: "E6EDF3",
                secondary: "8B949E",
                dimmed: "484F58",
                accent: "2F81F7",
                selection: "1F6FEB44",
                separator: "30363D",
                search: "161B22",
                statusBar: "010409",
                statusText: "8B949E",
                danger: "F85149",
                checkbox: "2F81F7"
            )
        }
    }
}
