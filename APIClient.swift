import Foundation

enum APIError: Error {
    case invalidResponse
    case httpStatus(Int)
}

final class APIClient {
    private let baseURL: URL
    private let urlSession: URLSession

    init(baseURL: URL = BackendConfig.baseURL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }

    func fetchAssets() async throws -> [AssetDTO] {
        let url = baseURL.appendingPathComponent("api/assets")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw APIError.httpStatus(http.statusCode) }

        return try JSONDecoder().decode([AssetDTO].self, from: data)
    }
}
