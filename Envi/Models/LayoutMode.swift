import Foundation

enum LayoutMode: String, CaseIterable, Identifiable {
    case sidebar
    case stacked

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sidebar: "Sidebar"
        case .stacked: "Stacked"
        }
    }
}
