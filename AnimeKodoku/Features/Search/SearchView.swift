import SwiftUI

@MainActor struct SearchView: View {
    @EnvironmentObject private var registry: SourceRegistry
    @EnvironmentObject private var store: LocalStore
    @StateObject private var model = SearchViewModel()
    @State private var query = ""
    @State private var scope: String
    init(initialSourceID: String = "all") { _scope = State(initialValue: initialSourceID) }
    private var searchable: [Source] { registry.enabled().filter { $0.source.supportsSearch }.map(\.source) }
    private var request: SearchRequest {
        SearchRequest(query: query, sourceIDs: searchable.filter { scope == "all" || $0.id == scope }.map(\.id), filters: store.preferences.sourceFilters)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Ambito", selection: $scope) { Text("Tutte le fonti").tag("all"); ForEach(searchable) { Text($0.name).tag($0.id) } }.labelsHidden()
                Spacer()
                if let adapter = try? registry.adapter(id: scope), !adapter.filters.isEmpty {
                    Menu {
                        ForEach(adapter.filters) { definition in
                            Picker(definition.title, selection: filterBinding(definition.id)) {
                                Text("Predefinito").tag("")
                                ForEach(definition.options, id: \.self) { Text($0).tag($0) }
                            }
                        }
                    } label: { Label("Filtri", systemImage: "line.3.horizontal.decrease.circle") }
                }
            }.padding(.horizontal).padding(.vertical, 8)
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                if store.preferences.searchHistory.isEmpty { EmptyState(title: "Trova una nuova storia", message: "Cerca in tutte le fonti o scegline una per usare i suoi filtri.", symbol: "magnifyingglass") }
                else {
                    List { Section("Ricerche recenti") { ForEach(store.preferences.searchHistory, id: \.self) { value in Button { query = value } label: { Label(value, systemImage: "clock") } }; Button("Cancella cronologia", role: .destructive) { store.preferences.searchHistory = [] } } }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: Design.grid, spacing: 24) {
                        ForEach(model.results) { anime in NavigationLink { DetailView(anime: anime) } label: { AnimeCard(anime: anime) }.buttonStyle(.plain) }
                    }.padding(16)
                    ForEach(model.errors.keys.sorted(), id: \.self) { id in ErrorState(message: "\(id): \(model.errors[id] ?? "Errore")") { Task { await model.loadMore(registry: registry, store: store) } } }
                    if model.loading { ProgressView("Ricerca…").padding() }
                    else if model.results.isEmpty && model.errors.isEmpty { EmptyState(title: "Nessun risultato", message: searchable.isEmpty ? "Abilita una fonte con ricerca in Esplora." : "Prova un altro titolo o modifica i filtri.", symbol: "magnifyingglass") }
                    if model.hasMore && !model.loading { Button("Carica altri risultati") { Task { await model.loadMore(registry: registry, store: store) } }.buttonStyle(.bordered).padding() }
                }
            }
        }.navigationTitle("Cerca").searchable(text: $query, prompt: "Titoli e nuove scoperte")
        .onSubmit(of: .search) { model.remember(query, store: store) }
        .task(id: request) { await model.restart(request: request, registry: registry, store: store) }
    }
    private func filterBinding(_ id: String) -> Binding<String> {
        Binding(get: { store.preferences.sourceFilters[scope]?.first(where: { $0.id == id })?.value ?? "" }, set: { value in
            var filters = store.preferences.sourceFilters[scope] ?? []; filters.removeAll { $0.id == id }
            if !value.isEmpty { filters.append(Filter(id: id, value: value)) }
            store.preferences.sourceFilters[scope] = filters
        })
    }
}
