import Foundation

struct AquaReading: Decodable, Identifiable, Equatable {
    let sensorID: String
    let name: String
    let type: String
    let role: String?
    let enabled: Bool?
    let visible: Bool?
    let sortOrder: Int?
    let temperatureC: Double?
    let rawTemperatureC: Double?
    let offset: Double?
    let min: Double?
    let max: Double?
    let status: String
    let crcOK: Bool?
    let error: String?

    var id: String {
        sensorID
    }

    var isAquariumVisible: Bool {
        if let role {
            return role == "aquarium"
                && enabled != false
                && visible != false
        }

        return type == "water"
    }

    enum CodingKeys: String, CodingKey {
        case sensorID = "sensor_id"
        case name
        case type
        case role
        case enabled
        case visible
        case sortOrder = "sort_order"
        case temperatureC = "temperature_c"
        case rawTemperatureC = "raw_temperature_c"
        case offset
        case min
        case max
        case status
        case crcOK = "crc_ok"
        case error
    }
}
