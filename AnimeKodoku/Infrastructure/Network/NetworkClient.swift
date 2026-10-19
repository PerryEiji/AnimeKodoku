import Foundation

actor NetworkClient {
    static let shared = NetworkClient()
    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 128 * 1024 * 1024, diskPath: "AnimeKodokuMetadata")
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 90
        session = URLSession(configuration: config)
    }
    func data(from url: URL) async throws -> Data {
        guard url.scheme == "https" else { throw AppError.message("È richiesto un URL HTTPS.") }
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw AppError.message("Risposta del server non valida.")
        }
        guard data.count <= 20 * 1024 * 1024 else { throw AppError.message("Risposta troppo grande.") }
        return data
    }
    func decode<T: Decodable & Sendable>(_ type: T.Type, from url: URL) async throws -> T {
        try JSONDecoder().decode(type, from: await data(from: url))
    }
}
