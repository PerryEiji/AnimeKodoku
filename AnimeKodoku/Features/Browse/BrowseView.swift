import SwiftUI
import UniformTypeIdentifiers

@MainActor struct BrowseView: View {
    @EnvironmentObject private var registry: SourceRegistry
    @EnvironmentObject private var store: LocalStore
    @State private var manifestURL = ""
    @State private var installing = false
    @State private var error: String?
    @State private var importing = false
    var body: some View {
        List {
            Section("Fonti installate") {
                ForEach(registry.adapters.map(\.source)) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "globe").foregroundStyle(Design.accent)
                            Text(source.name).font(.headline); Spacer(); Text(source.language.uppercased()).font(.caption).foregroundStyle(.secondary)
                        }
                        Toggle("Abilitata", isOn: Binding(get: { !store.preferences.disabledSourceIds.contains(source.id) }, set: { if $0 { store.preferences.disabledSourceIds.remove(source.id) } else { store.preferences.disabledSourceIds.insert(source.id) } }))
                        if !store.preferences.disabledSourceIds.contains(source.id) {
                            NavigationLink("Apri catalogo") { CatalogView(sourceID: source.id) }
                        } else { Label("Fonte disabilitata", systemImage: "pause.circle").font(.caption).foregroundStyle(.secondary) }
                    }.padding(.vertical, 4)
                }
            }
            Section {
                TextField("https://server/manifest.json", text: $manifestURL)
                    .textFieldStyle(.roundedBorder).autocorrectionDisabled()
                Button("Installa manifest REST") {
                    guard let url = URL(string: manifestURL) else { error = "Indirizzo non valido."; return }
                    installing = true
                    Task { do { try await registry.install(from: url); manifestURL = "" } catch { self.error = error.localizedDescription }; installing = false }
                }.disabled(installing || manifestURL.isEmpty)
                Button("Importa manifest JSON") { importing = true }
                if installing { ProgressView("Installazione…") }
            } header: { Text("Aggiungi fonte") } footer: { Text("Importa solo manifest di cui ti fidi. Sono supportate API REST; i runtime JS/WASM sono predisposti nel contratto ma non inclusi.") }
            Section { Text("Il catalogo Demo usa opere inventate. Nessun video o contenuto anime è incluso nell'app.").foregroundStyle(.secondary) }
        }.navigationTitle("Esplora")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do { let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; try registry.install(data: Data(contentsOf: url)) } catch { self.error = error.localizedDescription }
        }
        .alert("Fonte non installata", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
}
@MainActor struct CatalogView: View {
    let sourceID: String
    @EnvironmentObject private var registry: SourceRegistry
    @EnvironmentObject private var store: LocalStore
    @StateObject private var model = CatalogViewModel()
    private var adapter: (any SourceProtocol)? { try? registry.adapter(id: sourceID) }
    var body: some View {
        ScrollView {
            LazyVGrid(columns: Design.grid, spacing: 24) {
                ForEach(model.values) { anime in
                    NavigationLink { DetailView(anime: anime) } label: { AnimeCard(anime: anime) }.buttonStyle(.plain)
                        .onAppear { if anime.id == model.values.last?.id, let adapter { Task { await model.loadNext(source: adapter, store: store) } } }
                }
            }.padding(16)
            if model.loading { ProgressView("Caricamento…").padding() }
            if let error = model.error { ErrorState(message: error) { if let adapter { Task { await model.loadNext(source: adapter, store: store) } } } }
            if model.values.isEmpty && !model.loading && model.error == nil { EmptyState(title: "Catalogo vuoto", message: adapter == nil ? "La fonte è disabilitata o non disponibile." : "Questa fonte non ha ancora opere.", symbol: "globe") }
            if model.ended && !model.values.isEmpty { Text("Fine del catalogo").font(.caption).foregroundStyle(.secondary).padding() }
        }.navigationTitle(adapter?.source.name ?? "Catalogo")
        .toolbar { if adapter?.source.supportsSearch == true { NavigationLink { SearchView(initialSourceID: sourceID) } label: { Label("Cerca nella fonte", systemImage: "magnifyingglass") } } }
        .task { if let adapter { await model.restart(source: adapter, store: store) } }
        .refreshable { if let adapter { await model.restart(source: adapter, store: store) } }
    }
}
