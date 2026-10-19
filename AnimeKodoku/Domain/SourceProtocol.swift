import Foundation

public protocol SourceProtocol: Sendable {
    var source: Source { get }
    var filters: [FilterDefinition] { get }
    func getPopular(page: Int) async throws -> [Anime]
    func search(query: String, filters: [Filter]) async throws -> [Anime]
    // Paginated overload preserves query and filters for every next page.
    func search(query: String, filters: [Filter], page: Int) async throws -> [Anime]
    func getDetails(animeId: String) async throws -> Anime
    func getEpisodes(animeId: String) async throws -> [Episode]
}
public extension SourceProtocol {
    func search(query: String, filters: [Filter], page: Int) async throws -> [Anime] {
        guard page == 1 else { return [] }
        return try await search(query: query, filters: filters)
    }
}
public protocol TrackerService: Sendable {
    var name: String { get }
    func updateProgress(anime: Anime, episode: Episode) async throws
}
