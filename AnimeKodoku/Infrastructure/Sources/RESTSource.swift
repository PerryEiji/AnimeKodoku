import Foundation

struct RESTSource: SourceProtocol {
    let manifest: SourceManifest
    var source: Source { manifest.source }
    var filters: [FilterDefinition] { manifest.filters }
    func getPopular(page: Int) async throws -> [Anime] {
        try await fetch([Anime].self, path: "popular", items: [URLQueryItem(name: "page", value: String(page))])
    }
    func search(query: String, filters: [Filter]) async throws -> [Anime] { try await search(query: query, filters: filters, page: 1) }
    func search(query: String, filters: [Filter], page: Int) async throws -> [Anime] {
        guard source.supportsSearch else { throw AppError.message("Questa fonte non supporta la ricerca.") }
        let supported = filters.filter { filter in self.filters.contains { $0.id == filter.id && $0.options.contains(filter.value) } }
        let items = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "page", value: String(page))] + supported.map { URLQueryItem(name: "filter[\($0.id)]", value: $0.value) }
        return try await fetch([Anime].self, path: "search", items: items)
    }
    func getDetails(animeId: String) async throws -> Anime {
        let anime = try await fetch(Anime.self, path: "details", items: [URLQueryItem(name: "id", value: animeId)])
        guard anime.id == animeId else { throw AppError.message("La fonte ha restituito un'opera diversa da quella richiesta.") }
        return anime
    }
    func getEpisodes(animeId: String) async throws -> [Episode] {
        let episodes = try await fetch([Episode].self, path: "episodes", items: [URLQueryItem(name: "animeId", value: animeId)])
        guard episodes.allSatisfy({ $0.animeId == animeId && $0.number.isFinite && $0.duration.isFinite && $0.duration >= 0 && $0.progress.isFinite && $0.progress >= 0 }) else { throw AppError.message("La fonte ha restituito episodi non validi.") }
        return episodes
    }
    private func fetch<T: Decodable & Sendable>(_ type: T.Type, path: String, items: [URLQueryItem]) async throws -> T {
        var components = URLComponents(url: source.baseUrl.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = items
        guard let url = components?.url else { throw AppError.message("URL della fonte non valido.") }
        let value = try await NetworkClient.shared.decode(type, from: url)
        // Reject identities that could collide with another source's persisted data.
        let anime = (value as? [Anime]) ?? (value as? Anime).map { [$0] } ?? []
        guard anime.allSatisfy({ $0.sourceId == source.id && $0.id.hasPrefix(source.id + ":") }) else { throw AppError.message("La fonte ha restituito identità non valide.") }
        if let episodes = value as? [Episode] {
            guard episodes.allSatisfy({ $0.id.hasPrefix(source.id + ":") && $0.animeId.hasPrefix(source.id + ":") }) else { throw AppError.message("ID episodio non valido.") }
        }
        return value
    }
}
