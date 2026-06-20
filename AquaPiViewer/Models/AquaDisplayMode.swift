import Foundation
import CoreGraphics

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

    var windowSize: CGSize {
        switch self {
        case .normal:
            CGSize(width: 720, height: 886)
        case .compact:
            CGSize(width: 360, height: 474)
        }
    }
}
