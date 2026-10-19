import Foundation
import Combine

@MainActor final class CatalogViewModel: ObservableObject {
    @Published private(set) var values: [Anime] = []
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var ended = false
    private var page = 1
    private var generation = UUID()
    func restart(source: any SourceProtocol, store: LocalStore) async {
        generation = UUID(); page = 1; values = []; error = nil; ended = false; loading = false
        await loadNext(source: source, store: store)
    }
    func loadNext(source: any SourceProtocol, store: LocalStore) async {
        guard !loading, !ended else { return }
        let token = generation; loading = true; error = nil
        do {
            let next = try await source.getPopular(page: page)
            try Task.checkCancellation(); guard token == generation else { return }
            let known = Set(values.map(\.id)); var seen = known
            let added = next.filter { seen.insert($0.id).inserted }
            values += added; ended = next.isEmpty || added.isEmpty; page += 1
            store.cache(added)
        } catch is CancellationError { }
        catch { if token == generation { self.error = error.localizedDescription } }
        if token == generation { loading = false }
    }
}
