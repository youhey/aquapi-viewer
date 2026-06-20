import Foundation

enum AquaDisplayMode: String, CaseIterable, Identifiable {
    case normal
    case compact

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .normal:
            "Normal"
        case .compact:
            "Compact"
        }
    }
}
