import Foundation
import Combine

@MainActor final class DetailViewModel: ObservableObject {
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    func load(_ anime: Anime, registry: SourceRegistry, store: LocalStore) async {
        guard !loading else { return }; loading = true; error = nil; defer { loading = false }
        do {
            let source = try registry.adapter(id: anime.sourceId)
            async let details = source.getDetails(animeId: anime.id)
            async let episodes = source.getEpisodes(animeId: anime.id)
            let (value, values) = try await (details, episodes)
            try Task.checkCancellation()
            store.cache([value]); store.cacheEpisodes(values)
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
