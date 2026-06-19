import Foundation
import SwiftUI

enum FanMode: String, Decodable, Equatable {
    case auto
    case manualOn = "manual_on"
    case manualOff = "manual_off"
    case unknown
    case disabled

    init(apiValue: String?) {
        switch apiValue {
        case Self.auto.rawValue:
            self = .auto
        case Self.manualOn.rawValue:
            self = .manualOn
        case Self.manualOff.rawValue:
            self = .manualOff
        case Self.disabled.rawValue:
            self = .disabled
        default:
            self = .unknown
        }
    }

    var apiValue: String {
        rawValue
    }

    var label: String {
        switch self {
        case .auto:
            "Auto"
        case .manualOn:
            "On"
        case .manualOff:
            "Off"
        case .unknown:
            "Unknown"
        case .disabled:
            "Disabled"
        }
    }

    var iconName: String {
        switch self {
        case .auto:
            "fan.badge.automatic"
        case .manualOn:
            "fan.fill"
        case .manualOff:
            "fan.slash.fill"
        case .unknown:
            "questionmark.circle"
        case .disabled:
            "fan.slash"
        }
    }

    var color: Color {
        switch self {
        case .auto:
            .blue
        case .manualOn:
            .orange
        case .manualOff:
            .red
        case .unknown:
            .gray
        case .disabled:
            .gray.opacity(0.5)
        }
    }
}

enum FanState: String, Decodable, Equatable {
    case on
    case off
    case unknown
    case disabled

    init(apiValue: String?) {
        switch apiValue {
        case Self.on.rawValue:
            self = .on
        case Self.off.rawValue:
            self = .off
        case Self.disabled.rawValue:
            self = .disabled
        default:
            self = .unknown
        }
    }
}

struct AquaFan: Decodable, Equatable {
    let id: String
    let mode: String?
    let state: String?
    let reason: String?
}

struct AquaFansResponse: Decodable, Equatable {
    let fans: [AquaFan]
}

struct AquaFanResponse: Decodable, Equatable {
    let fan: AquaFan
}
