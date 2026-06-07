import Combine
import Foundation

@MainActor
final class AquariumIndexViewModel: ObservableObject {
    @Published private(set) var readings: [AquaReading] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published var errorMessage: String?

    private let client: AquaPiClient

    init(client: AquaPiClient? = nil) {
        self.client = client ?? AquaPiClient()
    }

    var waterSensors: [AquaReading] {
        readings.filter(\.isWaterSensor)
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
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
