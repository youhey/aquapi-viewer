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

    func fetchSummary() async throws -> AquaSummaryResponse {
        let url = baseURL.appendingPathComponent("api/summary")
        let data = try await fetchData(from: url)

        do {
            return try JSONDecoder().decode(AquaSummaryResponse.self, from: data)
        } catch {
            throw AquaPiClientError.decoding(error)
        }
    }

    func fetchFans() async throws -> [AquaFan] {
        let url = baseURL.appendingPathComponent("api/fans")
        let data = try await fetchData(from: url)

        do {
            return try JSONDecoder().decode(AquaFansResponse.self, from: data).fans
        } catch {
            throw AquaPiClientError.decoding(error)
        }
    }

    func setFanManualOn(id: String) async throws -> AquaFan {
        try await setFanMode(id: id, action: "manual-on")
    }

    func setFanManualOff(id: String) async throws -> AquaFan {
        try await setFanMode(id: id, action: "manual-off")
    }

    func setFanAuto(id: String) async throws -> AquaFan {
        try await setFanMode(id: id, action: "auto")
    }

    private func setFanMode(id: String, action: String) async throws -> AquaFan {
        let url = baseURL
            .appendingPathComponent("api/fans")
            .appendingPathComponent(id)
            .appendingPathComponent(action)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let data = try await fetchData(for: request)
        do {
            return try JSONDecoder().decode(AquaFanResponse.self, from: data).fan
        } catch {
            throw AquaPiClientError.decoding(error)
        }
    }

    private func fetchData(from url: URL) async throws -> Data {
        try await fetchData(for: URLRequest(url: url))
    }

    private func fetchData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AquaPiClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AquaPiClientError.httpStatus(
                httpResponse.statusCode,
                message: Self.errorMessage(from: data)
            )
        }

        return data
    }

    private static func errorMessage(from data: Data) -> String? {
        guard !data.isEmpty else {
            return nil
        }

        guard let payload = try? JSONDecoder().decode(AquaPiAPIErrorResponse.self, from: data) else {
            return nil
        }

        return payload.message ?? payload.error
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
    case httpStatus(Int, message: String?)
    case decoding(Error)

    var statusCode: Int? {
        switch self {
        case .httpStatus(let statusCode, _):
            statusCode
        case .invalidURL, .invalidResponse, .decoding:
            nil
        }
    }

    var apiMessage: String? {
        switch self {
        case .httpStatus(_, let message):
            message
        case .invalidURL, .invalidResponse, .decoding:
            nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "API URL を組み立てられませんでした。"
        case .invalidResponse:
            "API レスポンスを解釈できませんでした。"
        case .httpStatus(let statusCode, let message):
            if let message, !message.isEmpty {
                "API が HTTP \(statusCode) を返しました: \(message)"
            } else {
                "API が HTTP \(statusCode) を返しました。"
            }
        case .decoding(let error):
            "API レスポンスの JSON decode に失敗しました: \(error.localizedDescription)"
        }
    }
}

private struct AquaPiAPIErrorResponse: Decodable {
    let error: String?
    let message: String?
}
