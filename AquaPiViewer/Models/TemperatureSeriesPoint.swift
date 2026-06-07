import Foundation

struct TemperatureSeriesPoint: Codable, Identifiable {
    var id: Date {
        ts
    }

    let ts: Date
    let temperatureC: Double?
    let rawTemperatureC: Double?
    let status: String?
    let crcOk: Bool?

    enum CodingKeys: String, CodingKey {
        case ts
        case temperatureC = "temperature_c"
        case rawTemperatureC = "raw_temperature_c"
        case status
        case crcOk = "crc_ok"
    }

    init(
        ts: Date,
        temperatureC: Double?,
        rawTemperatureC: Double?,
        status: String?,
        crcOk: Bool?
    ) {
        self.ts = ts
        self.temperatureC = temperatureC
        self.rawTemperatureC = rawTemperatureC
        self.status = status
        self.crcOk = crcOk
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let tsText = try container.decode(String.self, forKey: .ts)

        guard let ts = Self.parseDate(tsText) else {
            throw DecodingError.dataCorruptedError(
                forKey: .ts,
                in: container,
                debugDescription: "Invalid ISO8601 timestamp: \(tsText)"
            )
        }

        self.ts = ts
        temperatureC = try container.decodeIfPresent(Double.self, forKey: .temperatureC)
        rawTemperatureC = try container.decodeIfPresent(Double.self, forKey: .rawTemperatureC)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        crcOk = try container.decodeIfPresent(Bool.self, forKey: .crcOk)
    }

    nonisolated private static func parseDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }
}
