import SwiftUI

@MainActor struct LibraryView: View {
    @EnvironmentObject private var store: LocalStore
    @EnvironmentObject private var sources: SourceRegistry
    @StateObject private var model = LibraryViewModel()
    @State private var filtersPresented = false
    @State private var confirmRemoval = false
    @State private var groupName = ""
    @State private var saveGroup = false
    private var values: [Anime] { model.values(store: store) }
    var body: some View {
        VStack(spacing: 0) {
            if store.preferences.libraryFilter != LibraryFilter() {
                HStack { Label("Filtri attivi", systemImage: "line.3.horizontal.decrease.circle.fill").font(.subheadline); Spacer(); Button("Azzera") { store.preferences.libraryFilter = LibraryFilter() } }.padding(.horizontal).padding(.vertical, 8)
            }
            if !store.preferences.groups.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(store.preferences.groups) { group in
                            Button(group.name) { store.preferences.libraryFilter = group.filter }.buttonStyle(.bordered)
                                .contextMenu { Button("Elimina gruppo", role: .destructive) { store.preferences.groups.removeAll { $0.id == group.id } } }
                        }
                    }.padding(.horizontal)
                }.padding(.vertical, 8)
            }
            if values.isEmpty {
                EmptyState(title: store.library.isEmpty ? "La tua prossima storia" : "Nessun risultato", message: store.library.isEmpty ? "Apri Esplora, scegli una fonte e aggiungi un'opera alla libreria." : "Modifica la ricerca o i filtri attivi.")
            } else if store.preferences.listMode {
                List(values) { anime in item(anime, row: true) }.listStyle(.plain)
            } else {
                ScrollView { LazyVGrid(columns: Design.grid, spacing: 24) { ForEach(values) { anime in item(anime, row: false) } }.padding(16) }
            }
            if model.selecting {
                HStack {
                    Text("\(model.selected.count) selezionati").font(.subheadline)
                    Spacer()
                    Menu("Stato") { ForEach(WatchStatus.allCases) { status in Button(status.label) { store.setStatus(status, ids: model.selected); model.endSelection() } } }.disabled(model.selected.isEmpty)
                    IconButton(title: "Rimuovi selezionati", symbol: "trash") { confirmRemoval = true }.disabled(model.selected.isEmpty)
                }.padding(.horizontal).background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Libreria").searchable(text: $model.query, prompt: "Nella tua libreria")
        .toolbar {
            ToolbarItemGroup {
                IconButton(title: store.preferences.listMode ? "Mostra griglia" : "Mostra lista", symbol: store.preferences.listMode ? "square.grid.2x2" : "list.bullet") { store.preferences.listMode.toggle() }
                IconButton(title: "Filtri libreria", symbol: "line.3.horizontal.decrease.circle") { filtersPresented = true }
                Button(model.selecting ? "Fine" : "Seleziona") { if model.selecting { model.endSelection() } else { model.selecting = true } }
            }
        }
        .sheet(isPresented: $filtersPresented) { filterPanel }
        .confirmationDialog("Rimuovere \(model.selected.count) opere dalla libreria?", isPresented: $confirmRemoval, titleVisibility: .visible) { Button("Rimuovi dalla libreria", role: .destructive) { store.remove(ids: model.selected); model.endSelection() } }
        .alert("Salva gruppo di filtri", isPresented: $saveGroup) {
            TextField("Nome", text: $groupName)
            Button("Salva") { let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines); if !name.isEmpty { store.preferences.groups.append(SavedGroup(name: name, filter: store.preferences.libraryFilter)) }; groupName = "" }
            Button("Annulla", role: .cancel) { }
        }
    }
    @ViewBuilder private func item(_ anime: Anime, row: Bool) -> some View {
        if model.selecting {
            Button { model.toggle(anime.id) } label: {
                if row { HStack { AnimeRow(anime: anime); Image(systemName: model.selected.contains(anime.id) ? "checkmark.circle.fill" : "circle") } }
                else { AnimeCard(anime: anime, selected: model.selected.contains(anime.id)) }
            }.buttonStyle(.plain)
        } else {
            NavigationLink { DetailView(anime: anime) } label: { if row { AnimeRow(anime: anime) } else { AnimeCard(anime: anime) } }.buttonStyle(.plain)
        }
    }
    private var filterPanel: some View {
        NavigationStack {
            Form {
                Picker("Stato", selection: $store.preferences.libraryFilter.status) {
                    Text("Tutti").tag(Optional<WatchStatus>.none)
                    ForEach(WatchStatus.allCases) { Text($0.label).tag(Optional($0)) }
                }
                Picker("Fonte", selection: $store.preferences.libraryFilter.sourceId) {
                    Text("Tutte").tag(Optional<String>.none)
                    ForEach(sources.adapters.map(\.source)) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Tag", selection: $store.preferences.libraryFilter.tag) {
                    Text("Tutti").tag(Optional<String>.none)
                    ForEach(Array(Set(store.anime.flatMap(\.tags))).sorted(), id: \.self) { Text($0).tag(Optional($0)) }
                }
                Button("Salva come gruppo") { filtersPresented = false; saveGroup = true }
                Button("Azzera filtri") { store.preferences.libraryFilter = LibraryFilter() }
            }.navigationTitle("Filtri").toolbar { Button("Fine") { filtersPresented = false } }
        }.frame(minWidth: 300, minHeight: 340)
    }
}
