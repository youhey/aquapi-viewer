import Foundation

struct AquaPiClient {
    var baseURL: URL
    var session: URLSession

    init(
        baseURL: URL = URL(string: "http://aquapi:8080")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchReadings() async throws -> AquaReadingsResponse {
        let url = baseURL.appendingPathComponent("api/readings")
        let data = try await fetchData(from: url)

        do {
            return try JSONDecoder().decode(AquaReadingsResponse.self, from: data)
        } catch {
            throw AquaPiClientError.decoding(error)
        }
    }

    func fetchTemperatureSeries(
        sensorId: String,
        range: String = "24h"
    ) async throws -> TemperatureSeriesResponse {
        let url = try seriesURL(sensorId: sensorId, range: range)
        let data = try await fetchData(from: url)

        do {
            return try JSONDecoder().decode(TemperatureSeriesResponse.self, from: data)
        } catch {
            throw AquaPiClientError.decoding(error)
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AquaPiClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AquaPiClientError.httpStatus(httpResponse.statusCode)
        }

        return data
    }

    private func seriesURL(sensorId: String, range: String) throws -> URL {
        let url = baseURL.appendingPathComponent("api/readings/series")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw AquaPiClientError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "sensor_id", value: sensorId),
            URLQueryItem(name: "range", value: range)
        ]

        guard let seriesURL = components.url else {
            throw AquaPiClientError.invalidURL
        }

        return seriesURL
    }
}

enum AquaPiClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "API URL を組み立てられませんでした。"
        case .invalidResponse:
            "API レスポンスを解釈できませんでした。"
        case .httpStatus(let statusCode):
            "API が HTTP \(statusCode) を返しました。"
        case .decoding(let error):
            "API レスポンスの JSON decode に失敗しました: \(error.localizedDescription)"
        }
    }
}
