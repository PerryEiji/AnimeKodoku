import Foundation

// Demo catalogue only. All metadata is fictional; no media is bundled.
struct MockSource: SourceProtocol {
    let source = Source(id: "demo", name: "AnimeKodoku Demo", baseUrl: URL(string: "https://example.org")!, language: "it")
    let filters = [FilterDefinition(id: "tag", title: "Genere", options: ["Avventura", "Fantascienza", "Slice of life"]), FilterDefinition(id: "sort", title: "Ordina", options: ["Titolo A–Z", "Titolo Z–A"])]
    private var catalogue: [Anime] {
        (1...48).map { i in
            let names = ["Oltre l'orizzonte", "Cronache di Aster", "L'ultimo treno di Kyoto", "Il giardino delle stelle", "Vento d'estate", "Orbita Zero"]
            return Anime(id: "demo:\(i)", sourceId: "demo", title: "\(names[(i-1) % names.count]) · \((i-1)/6+1)", description: "Un viaggio tra incontri inattesi, luoghi lontani e nuove possibilità. Opera dimostrativa inventata per esplorare l'interfaccia di AnimeKodoku. I video di prova, se configurati, sono esterni e non rappresentano quest'opera.", status: i % 3 == 0 ? .finished : .airing, tags: [filters[0].options[(i-1) % 3]])
        }
    }
    func getPopular(page: Int) async throws -> [Anime] {
        try await Task.sleep(for: .milliseconds(180)); try Task.checkCancellation()
        return slice(catalogue, page: page)
    }
    func search(query: String, filters: [Filter]) async throws -> [Anime] { try await search(query: query, filters: filters, page: 1) }
    func search(query: String, filters: [Filter], page: Int) async throws -> [Anime] {
        try await Task.sleep(for: .milliseconds(180)); try Task.checkCancellation()
        var values = catalogue.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
        if let tag = filters.first(where: { $0.id == "tag" })?.value { values = values.filter { $0.tags.contains(tag) } }
        values.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        if filters.first(where: { $0.id == "sort" })?.value == "Titolo Z–A" { values.reverse() }
        return slice(values, page: page)
    }
    func getDetails(animeId: String) async throws -> Anime {
        guard let anime = catalogue.first(where: { $0.id == animeId }) else { throw AppError.message("Opera non trovata.") }
        return anime
    }
    func getEpisodes(animeId: String) async throws -> [Episode] {
        _ = try await getDetails(animeId: animeId)
        return (1...12).map { Episode(id: "\(animeId):ep\($0)", animeId: animeId, number: Double($0), title: "Episodio \($0)", videoUrl: AppConfiguration.demoVideoURL, subtitleUrl: AppConfiguration.demoSubtitleURL) }
    }
    private func slice(_ values: [Anime], page: Int) -> [Anime] {
        guard page > 0 else { return [] }
        let start = (page-1)*24
        guard start < values.count else { return [] }
        return Array(values[start..<min(start+24, values.count)])
    }
}
