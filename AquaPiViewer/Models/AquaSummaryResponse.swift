import Foundation

struct AquaSummaryResponse: Decodable, Equatable {
    let tanks: [AquaTankSummary]
}

struct AquaTankSummary: Decodable, Equatable {
    let sensorID: String
    let displayCode: String?
    let fanID: String?
    let fanState: String?
    let fanMode: String?
    let fanReason: String?

    enum CodingKeys: String, CodingKey {
        case sensorID = "sensor_id"
        case displayCode = "display_code"
        case fanControl = "fan_control"
        case fanID = "fan_id"
        case fanState = "fan_state"
        case fanMode = "fan_mode"
        case fanReason = "fan_reason"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let nestedFanControl = try container.decodeIfPresent(AquaTankFanControl.self, forKey: .fanControl)
        let topLevelFanReason = try container.decodeIfPresent(String.self, forKey: .fanReason)
        let nestedFanReason = nestedFanControl?.reason
        let resolvedFanReason = topLevelFanReason ?? nestedFanReason
        let nestedFanEnabled = nestedFanControl?.enabled

        sensorID = try container.decode(String.self, forKey: .sensorID)
        displayCode = try container.decodeIfPresent(String.self, forKey: .displayCode)
        fanID = try container.decodeIfPresent(String.self, forKey: .fanID) ?? nestedFanControl?.fanID
        fanReason = resolvedFanReason

        if nestedFanEnabled == false {
            fanState = "disabled"
            fanMode = FanMode.disabled.apiValue
        } else {
            fanState = try container.decodeIfPresent(String.self, forKey: .fanState) ?? nestedFanControl?.state
            fanMode = try container.decodeIfPresent(String.self, forKey: .fanMode)
                ?? nestedFanControl?.mode
                ?? Self.inferFanMode(from: resolvedFanReason)
        }
    }

    private static func inferFanMode(from reason: String?) -> String? {
        switch reason {
        case "manual_on":
            FanMode.manualOn.apiValue
        case "manual_off":
            FanMode.manualOff.apiValue
        case "tank_fan_control_disabled":
            FanMode.disabled.apiValue
        case let reason? where reason.hasPrefix("temperature_"):
            FanMode.auto.apiValue
        default:
            nil
        }
    }
}

private struct AquaTankFanControl: Decodable, Equatable {
    let enabled: Bool?
    let fanID: String?
    let state: String?
    let mode: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case enabled
        case fanID = "fan_id"
        case state
        case mode
        case reason
    }
}
