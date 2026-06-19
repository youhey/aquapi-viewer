import Foundation

struct AquaReading: Decodable, Identifiable, Equatable {
    let sensorID: String
    let name: String
    let type: String
    let role: String?
    let enabled: Bool?
    let visible: Bool?
    let sortOrder: Int?
    let displayCode: String?
    let temperatureC: Double?
    let rawTemperatureC: Double?
    let offset: Double?
    let min: Double?
    let max: Double?
    let status: String
    let crcOK: Bool?
    let error: String?
    let fanID: String?
    let fanState: String?
    let fanMode: String?
    let fanReason: String?

    init(
        sensorID: String,
        name: String,
        type: String,
        role: String?,
        enabled: Bool?,
        visible: Bool?,
        sortOrder: Int?,
        displayCode: String? = nil,
        temperatureC: Double?,
        rawTemperatureC: Double?,
        offset: Double?,
        min: Double?,
        max: Double?,
        status: String,
        crcOK: Bool?,
        error: String?,
        fanID: String? = nil,
        fanState: String? = nil,
        fanMode: String? = nil,
        fanReason: String? = nil
    ) {
        self.sensorID = sensorID
        self.name = name
        self.type = type
        self.role = role
        self.enabled = enabled
        self.visible = visible
        self.sortOrder = sortOrder
        self.displayCode = displayCode
        self.temperatureC = temperatureC
        self.rawTemperatureC = rawTemperatureC
        self.offset = offset
        self.min = min
        self.max = max
        self.status = status
        self.crcOK = crcOK
        self.error = error
        self.fanID = fanID
        self.fanState = fanState
        self.fanMode = fanMode
        self.fanReason = fanReason
    }

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

    var hasFanControl: Bool {
        guard let fanID else {
            return false
        }

        return !fanID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var effectiveFanMode: FanMode {
        if FanState(apiValue: fanState) == .disabled {
            return .disabled
        }

        return FanMode(apiValue: fanMode)
    }

    var effectiveFanState: FanState {
        FanState(apiValue: fanState)
    }

    func applyingFanSummary(_ summary: AquaTankSummary) -> AquaReading {
        AquaReading(
            sensorID: sensorID,
            name: name,
            type: type,
            role: role,
            enabled: enabled,
            visible: visible,
            sortOrder: sortOrder,
            displayCode: summary.displayCode ?? displayCode,
            temperatureC: temperatureC,
            rawTemperatureC: rawTemperatureC,
            offset: offset,
            min: min,
            max: max,
            status: status,
            crcOK: crcOK,
            error: error,
            fanID: summary.fanID ?? fanID,
            fanState: summary.fanState ?? fanState,
            fanMode: summary.fanMode ?? fanMode,
            fanReason: summary.fanReason ?? fanReason
        )
    }

    enum CodingKeys: String, CodingKey {
        case sensorID = "sensor_id"
        case name
        case type
        case role
        case enabled
        case visible
        case sortOrder = "sort_order"
        case displayCode = "display_code"
        case temperatureC = "temperature_c"
        case rawTemperatureC = "raw_temperature_c"
        case offset
        case min
        case max
        case status
        case crcOK = "crc_ok"
        case error
        case fanID = "fan_id"
        case fanState = "fan_state"
        case fanMode = "fan_mode"
        case fanReason = "fan_reason"
    }
}
