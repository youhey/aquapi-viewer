import Combine
import Foundation

@MainActor
final class AquariumIndexViewModel: ObservableObject {
    @Published private(set) var readings: [AquaReading] = []
    @Published private(set) var temperatureSeriesBySensorId: [String: TemperatureSeriesResponse] = [:]
    @Published private(set) var temperatureSeriesErrorsBySensorId: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    private let client: AquaPiClient

    init(client: AquaPiClient? = nil) {
        self.client = client ?? AquaPiClient()
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
            readings = response.sensors
            lastUpdated = response.generatedAt ?? Date()
            await reloadTemperatureSeries(for: visibleAquariumSensors)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
            }
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
