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
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AquaPiClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AquaPiClientError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(AquaReadingsResponse.self, from: data)
        } catch {
            throw AquaPiClientError.decoding(error)
        }
    }
}

enum AquaPiClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "API レスポンスを解釈できませんでした。"
        case .httpStatus(let statusCode):
            "API が HTTP \(statusCode) を返しました。"
        case .decoding(let error):
            "API レスポンスの JSON decode に失敗しました: \(error.localizedDescription)"
        }
    }
}
