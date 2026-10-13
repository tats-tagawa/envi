import AppKit
import SwiftUI

/// RGB color that survives UserDefaults / JSON.
struct CodableColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(hex: String, opacity: Double = 1) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: value).scanHexInt64(&rgb)
        switch value.count {
        case 8:
            red = Double((rgb >> 24) & 0xFF) / 255
            green = Double((rgb >> 16) & 0xFF) / 255
            blue = Double((rgb >> 8) & 0xFF) / 255
            self.opacity = Double(rgb & 0xFF) / 255
        case 6:
            red = Double((rgb >> 16) & 0xFF) / 255
            green = Double((rgb >> 8) & 0xFF) / 255
            blue = Double(rgb & 0xFF) / 255
            self.opacity = opacity
        default:
            red = 0
            green = 0
            blue = 0
            self.opacity = opacity
        }
    }

    init(_ color: Color) {
        let ns = NSColor(color)
        let converted = ns.usingColorSpace(.sRGB) ?? ns
        red = Double(converted.redComponent)
        green = Double(converted.greenComponent)
        blue = Double(converted.blueComponent)
        opacity = Double(converted.alphaComponent)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: opacity)
    }
}
