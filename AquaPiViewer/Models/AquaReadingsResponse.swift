import Foundation

struct AquaReadingsResponse: Decodable, Equatable {
    let generatedAt: Date?
    let sensors: [AquaReading]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case sensors
    }

    init(generatedAt: Date?, sensors: [AquaReading]) {
        self.generatedAt = generatedAt
        self.sensors = sensors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let generatedAtText = try container.decodeIfPresent(String.self, forKey: .generatedAt)

        generatedAt = generatedAtText.flatMap(Self.parseGeneratedAt)
        sensors = try container.decode([AquaReading].self, forKey: .sensors)
    }

    nonisolated private static func parseGeneratedAt(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }
}
