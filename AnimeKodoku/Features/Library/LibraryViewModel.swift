import Foundation
import Combine

@MainActor final class LibraryViewModel: ObservableObject {
    @Published var selecting = false
    @Published var selected: Set<String> = []
    @Published var query = ""
    func values(store: LocalStore) -> [Anime] {
        store.library.compactMap { entry in store.anime.first { $0.id == entry.animeId }.map { (entry, $0) } }
            .filter { store.preferences.libraryFilter.matches($0.1, entry: $0.0) && (query.isEmpty || $0.1.title.localizedCaseInsensitiveContains(query)) }
            .sorted { $0.0.addedAt > $1.0.addedAt }.map { $0.1 }
    }
    func toggle(_ id: String) { if !selected.insert(id).inserted { selected.remove(id) } }
    func endSelection() { selecting = false; selected = [] }
}
