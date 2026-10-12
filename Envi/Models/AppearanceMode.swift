import AppKit
import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Always an explicit scheme so SwiftUI does not stick on a previous Light/Dark override.
    var colorScheme: ColorScheme {
        switch self {
        case .system: Self.systemColorScheme
        case .light: .light
        case .dark: .dark
        }
    }

    /// `nil` follows the macOS appearance for AppKit views (e.g. the note body).
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// System Light/Dark from macOS (independent of any `NSApp.appearance` override).
    static var systemColorScheme: ColorScheme {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
    }

    static let storageKey = "appearanceMode"

    /// Posted by macOS when the user changes Light/Dark in System Settings.
    static let systemThemeChanged = Notification.Name("AppleInterfaceThemeChangedNotification")
}
