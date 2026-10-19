import Foundation
import Combine

struct SearchRequest: Hashable {
    var query: String
    var sourceIDs: [String]
    var filters: [String: [Filter]]
}
private struct SourceSearchResult: Sendable {
    var id: String
    var values: [Anime]?
    var error: String?
}
@MainActor final class SearchViewModel: ObservableObject {
    @Published private(set) var results: [Anime] = []
    @Published private(set) var loading = false
    @Published private(set) var errors: [String: String] = [:]
    @Published private(set) var hasMore = false
    private var pages: [String: Int] = [:]
    private var ended: Set<String> = []
    private var generation = UUID()
    private var activeRequest: SearchRequest?
    func restart(request: SearchRequest, registry: SourceRegistry, store: LocalStore) async {
        let token = UUID(); generation = token; activeRequest = request
        results = []; errors = [:]; pages = [:]; ended = []; hasMore = false; loading = false
        guard !request.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do { try await Task.sleep(for: .milliseconds(350)); try Task.checkCancellation() } catch { return }
        guard generation == token else { return }
        await loadMore(registry: registry, store: store)
    }
    func remember(_ query: String, store: LocalStore) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        store.preferences.searchHistory.removeAll { $0 == text }
        store.preferences.searchHistory.insert(text, at: 0)
        store.preferences.searchHistory = Array(store.preferences.searchHistory.prefix(20))
    }
    func loadMore(registry: SourceRegistry, store: LocalStore) async {
        guard !loading, let request = activeRequest else { return }
        let adapters = registry.enabled().filter { request.sourceIDs.contains($0.source.id) && $0.source.supportsSearch && !ended.contains($0.source.id) }
        guard !adapters.isEmpty else { hasMore = false; return }
        let token = generation; loading = true
        let pageSnapshot = pages
        let responses = await withTaskGroup(of: SourceSearchResult.self, returning: [SourceSearchResult].self) { group in
            for adapter in adapters {
                group.addTask {
                    do { return SourceSearchResult(id: adapter.source.id, values: try await adapter.search(query: request.query, filters: request.filters[adapter.source.id] ?? [], page: pageSnapshot[adapter.source.id] ?? 1)) }
                    catch { return SourceSearchResult(id: adapter.source.id, error: error.localizedDescription) }
                }
            }
            var values: [SourceSearchResult] = []; for await response in group { values.append(response) }; return values
        }
        guard generation == token else { return }
        guard !Task.isCancelled else { loading = false; return }
        for response in responses.sorted(by: { $0.id < $1.id }) {
            if let error = response.error { errors[response.id] = error; continue }
            errors[response.id] = nil
            let next = response.values ?? []
            var seen = Set(results.map(\.id)); let added = next.filter { seen.insert($0.id).inserted }
            results += added
            if next.isEmpty || added.isEmpty { ended.insert(response.id) }
            pages[response.id] = (pages[response.id] ?? 1) + 1
        }
        store.cache(results); loading = false
        hasMore = adapters.contains { !ended.contains($0.source.id) }
    }
}
