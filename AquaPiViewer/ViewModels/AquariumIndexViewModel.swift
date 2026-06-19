import Combine
import Foundation

@MainActor
final class AquariumIndexViewModel: ObservableObject {
    @Published private(set) var readings: [AquaReading] = []
    @Published private(set) var temperatureSeriesBySensorId: [String: TemperatureSeriesResponse] = [:]
    @Published private(set) var temperatureSeriesErrorsBySensorId: [String: String] = [:]
    @Published private(set) var fanOperationFanIds: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?
    @Published var fanControlErrorMessage: String?

    private let client: AquaPiClient
    private let logger: AppEventLogger

    init(client: AquaPiClient? = nil, logger: AppEventLogger? = nil) {
        self.client = client ?? AquaPiClient()
        self.logger = logger ?? AppEventLogger()
    }

    var visibleAquariumSensors: [AquaReading] {
        readings
            .filter(\.isAquariumVisible)
            .sorted(by: Self.compareAquariumDisplayOrder)
    }

    func loadIfNeeded() async {
        guard readings.isEmpty else {
            return
        }

        await reload()
    }

    func reload() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await client.fetchReadings()
            let summary = try await fetchSummaryForFanState()
            readings = Self.readings(response.sensors, applying: summary)
            lastUpdated = response.generatedAt ?? Date()
            await reloadTemperatureSeries(for: visibleAquariumSensors)
        } catch {
            errorMessage = error.localizedDescription
            logAPIError(endpoint: "/api/readings", error: error)
        }

        isLoading = false
    }

    func isFanOperationInProgress(for sensor: AquaReading) -> Bool {
        guard let fanID = sensor.fanID else {
            return false
        }

        return fanOperationFanIds.contains(fanID)
    }

    func setFanMode(_ mode: FanMode, for sensor: AquaReading) async {
        guard let fanID = sensor.fanID?.trimmingCharacters(in: .whitespacesAndNewlines), !fanID.isEmpty else {
            return
        }

        guard !fanOperationFanIds.contains(fanID) else {
            return
        }

        fanControlErrorMessage = nil
        fanOperationFanIds.insert(fanID)
        logger.log(
            "fan_mode_change_requested",
            fields: [
                "fan_id": fanID,
                "tank_id": sensor.sensorID,
                "tank_display_code": sensor.displayCode ?? sensor.sensorID,
                "from_mode": sensor.effectiveFanMode.apiValue,
                "to_mode": mode.apiValue
            ]
        )

        do {
            let fan = try await updateFanMode(mode, fanID: fanID)
            logger.log(
                "fan_mode_changed",
                fields: [
                    "fan_id": fanID,
                    "tank_id": sensor.sensorID,
                    "tank_display_code": sensor.displayCode ?? sensor.sensorID,
                    "to_mode": mode.apiValue,
                    "state": fan.state ?? "unknown",
                    "result": "success"
                ]
            )
            fanControlErrorMessage = nil
            await reload()
        } catch {
            let message = (error as? AquaPiClientError)?.apiMessage ?? error.localizedDescription
            fanControlErrorMessage = "Failed to update \(fanID): \(message)"
            var fields: [String: Any] = [
                "fan_id": fanID,
                "tank_id": sensor.sensorID,
                "tank_display_code": sensor.displayCode ?? sensor.sensorID,
                "to_mode": mode.apiValue,
                "message": message
            ]
            if let statusCode = (error as? AquaPiClientError)?.statusCode {
                fields["status_code"] = statusCode
            }
            logger.log("fan_mode_change_failed", fields: fields)
        }

        fanOperationFanIds.remove(fanID)
    }

    private func reloadTemperatureSeries(for sensors: [AquaReading]) async {
        temperatureSeriesBySensorId = [:]
        temperatureSeriesErrorsBySensorId = [:]

        for sensor in sensors {
            do {
                temperatureSeriesBySensorId[sensor.sensorID] = try await client.fetchTemperatureSeries(
                    sensorId: sensor.sensorID
                )
            } catch {
                temperatureSeriesBySensorId.removeValue(forKey: sensor.sensorID)
                temperatureSeriesErrorsBySensorId[sensor.sensorID] = error.localizedDescription
                logAPIError(endpoint: "/api/readings/series", error: error)
            }
        }
    }

    private func fetchSummaryForFanState() async throws -> AquaSummaryResponse? {
        do {
            return try await client.fetchSummary()
        } catch {
            logAPIError(endpoint: "/api/summary", error: error)
            return nil
        }
    }

    private func updateFanMode(_ mode: FanMode, fanID: String) async throws -> AquaFan {
        switch mode {
        case .auto:
            try await client.setFanAuto(id: fanID)
        case .manualOn:
            try await client.setFanManualOn(id: fanID)
        case .manualOff:
            try await client.setFanManualOff(id: fanID)
        case .unknown, .disabled:
            throw AquaPiFanControlError.unsupportedMode
        }
    }

    private func logAPIError(endpoint: String, error: Error) {
        var fields: [String: Any] = [
            "endpoint": endpoint,
            "message": error.localizedDescription
        ]
        if let statusCode = (error as? AquaPiClientError)?.statusCode {
            fields["status_code"] = statusCode
        }
        logger.log("aquapi_api_error", fields: fields)
    }

    private static func readings(
        _ readings: [AquaReading],
        applying summary: AquaSummaryResponse?
    ) -> [AquaReading] {
        guard let summary else {
            return readings
        }

        let summariesBySensorId = Dictionary(
            uniqueKeysWithValues: summary.tanks.map { ($0.sensorID, $0) }
        )

        return readings.map { reading in
            guard let summary = summariesBySensorId[reading.sensorID] else {
                return reading
            }
            return reading.applyingFanSummary(summary)
        }
    }

    private static func compareAquariumDisplayOrder(_ lhs: AquaReading, _ rhs: AquaReading) -> Bool {
        let lhsSort = lhs.sortOrder ?? 1000
        let rhsSort = rhs.sortOrder ?? 1000

        if lhsSort != rhsSort {
            return lhsSort < rhsSort
        }

        if lhs.name != rhs.name {
            return lhs.name < rhs.name
        }

        return lhs.sensorID < rhs.sensorID
    }
}

private enum AquaPiFanControlError: LocalizedError {
    case unsupportedMode

    var errorDescription: String? {
        switch self {
        case .unsupportedMode:
            "このファンモードは操作できません。"
        }
    }
}
