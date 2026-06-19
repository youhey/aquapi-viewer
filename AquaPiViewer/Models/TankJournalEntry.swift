import Foundation

struct TankJournalEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var tankId: String
    var tankDisplayCode: String?
    var tankName: String?
    var kind: TankJournalKind
    var text: String
    var occurredAt: Date
    var createdAt: Date
    var updatedAt: Date
}

enum TankJournalKind: String, Codable, CaseIterable {
    case feeding
    case cleaning
    case waterTopUp
    case note

    var displayName: String {
        switch self {
        case .feeding:
            "餌やり"
        case .cleaning:
            "掃除/水換え"
        case .waterTopUp:
            "水足し"
        case .note:
            "自由メモ"
        }
    }

    var defaultText: String {
        switch self {
        case .feeding:
            "餌やり"
        case .cleaning:
            "掃除/水換え"
        case .waterTopUp:
            "水足し"
        case .note:
            ""
        }
    }

    var iconName: String {
        switch self {
        case .feeding:
            "carrot.fill"
        case .cleaning:
            "bubbles.and.sparkles.fill"
        case .waterTopUp:
            "drop.fill"
        case .note:
            "square.and.pencil.circle.fill"
        }
    }
}

enum TankJournalDayPart: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .morning:
            "朝"
        case .afternoon:
            "昼"
        case .evening:
            "晩"
        }
    }

    init(hour: Int) {
        switch hour {
        case 4...10:
            self = .morning
        case 11...16:
            self = .afternoon
        default:
            self = .evening
        }
    }
}

struct TankJournalDayPartSummary: Equatable {
    var morning: Int
    var afternoon: Int
    var evening: Int

    static let empty = TankJournalDayPartSummary(morning: 0, afternoon: 0, evening: 0)

    var displayText: String {
        "Today: 朝\(morning) 昼\(afternoon) 晩\(evening)"
    }
}
