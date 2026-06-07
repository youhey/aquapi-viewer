import Foundation

struct TemperatureSeriesResponse: Codable {
    let sensorId: String
    let name: String?
    let range: String
    let points: [TemperatureSeriesPoint]

    enum CodingKeys: String, CodingKey {
        case sensorId = "sensor_id"
        case name
        case range
        case points
    }
}
