enum WaterSafetyStatus: String {
    case safety
    case warning
    case danger
    case unknown

    var label: String {
        switch self {
        case .safety:
            "Safety"
        case .warning:
            "Warning"
        case .danger:
            "Danger"
        case .unknown:
            "Unknown"
        }
    }

    var shortLabel: String {
        switch self {
        case .safety:
            "SAFE"
        case .warning:
            "WARN"
        case .danger:
            "DANGER"
        case .unknown:
            "UNK"
        }
    }
}
