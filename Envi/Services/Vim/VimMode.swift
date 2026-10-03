import Foundation

enum VimMode: Equatable {
    case normal
    case insert
    case visual
    case visualLine

    var statusLabel: String {
        switch self {
        case .normal: "-- NORMAL --"
        case .insert: "-- INSERT --"
        case .visual: "-- VISUAL --"
        case .visualLine: "-- VISUAL LINE --"
        }
    }

    var isVisual: Bool {
        self == .visual || self == .visualLine
    }
}
