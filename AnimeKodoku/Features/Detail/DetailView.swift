import SwiftUI

@MainActor struct DetailView: View {
    let anime: Anime
    @EnvironmentObject private var store: LocalStore
    @EnvironmentObject private var registry: SourceRegistry
    @EnvironmentObject private var app: AppContainer
    @EnvironmentObject private var downloads: DownloadManager
    @StateObject private var model = DetailViewModel()
    @State private var ascending = true
    @State private var remove = false
    private var current: Anime { store.anime.first { $0.id == anime.id } ?? anime }
    private var entry: LibraryEntry? { store.library.first { $0.animeId == anime.id } }
    private var episodes: [Episode] { store.episodes.filter { $0.animeId == anime.id }.sorted { ascending ? $0.number < $1.number : $0.number > $1.number } }
    private var resume: Episode? {
        if let id = entry?.lastEpisodeId, let episode = episodes.first(where: { $0.id == id }), !episode.isWatched { return episode }
        return episodes.sorted { $0.number < $1.number }.first { !$0.isWatched } ?? episodes.last
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Color.clear.frame(height: 230).overlay { CoverArt(anime: current, banner: true) }.clipped()
                    .overlay(alignment: .bottomLeading) { Text("ANIMEKODOKU").font(.caption.bold()).tracking(3).foregroundStyle(.white.opacity(0.8)).padding(20) }
                VStack(alignment: .leading, spacing: 16) {
                    Text(current.title).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                    Text(current.tags.joined(separator: " · ")).font(.subheadline).foregroundStyle(Design.accent)
                    ViewThatFits(in: .horizontal) {
                        HStack { primaryActions }
                        VStack(alignment: .leading) { primaryActions }
                    }
                    if entry != nil {
                        Picker("Stato", selection: Binding(get: { entry?.status ?? .planning }, set: { store.setStatus($0, ids: [anime.id]) })) { ForEach(WatchStatus.allCases) { Text($0.label).tag($0) } }
                    }
                    Text(current.description).font(.body).foregroundStyle(.secondary).textSelection(.enabled)
                    HStack { Text("Episodi").font(.title2.bold()); Spacer(); IconButton(title: "Inverti ordine episodi", symbol: "arrow.up.arrow.down") { ascending.toggle() } }
                    if model.loading { ProgressView("Aggiornamento episodi…") }
                    if let error = model.error { ErrorState(message: error) { Task { await model.load(anime, registry: registry, store: store) } } }
                    if episodes.isEmpty && !model.loading { EmptyState(title: "Nessun episodio", message: "La fonte non ha restituito episodi e non sono presenti dati locali.", symbol: "play.rectangle") }
                    LazyVStack(spacing: 0) { ForEach(episodes) { episode in episodeRow(episode); Divider() } }
                }.padding(.horizontal, 20).padding(.bottom, 32)
            }
        }.navigationTitle("")
        .task { await model.load(anime, registry: registry, store: store) }
        .confirmationDialog("Rimuovere quest'opera dalla libreria?", isPresented: $remove, titleVisibility: .visible) { Button("Rimuovi", role: .destructive) { store.remove(ids: [anime.id]) } }
    }
    @ViewBuilder private var primaryActions: some View {
        if let resume { Button { app.play(current, episode: resume) } label: { Label((entry?.lastProgress ?? 0) > 0 ? "Riprendi" : "Guarda", systemImage: "play.fill") }.buttonStyle(.borderedProminent).controlSize(.large) }
        if entry == nil { Button { store.add(current) } label: { Label("Aggiungi a libreria", systemImage: "plus") }.buttonStyle(.bordered).controlSize(.large) }
        else { Button { remove = true } label: { Label("In libreria", systemImage: "checkmark") }.buttonStyle(.bordered).controlSize(.large) }
    }
    private func episodeRow(_ episode: Episode) -> some View {
        HStack(spacing: 12) {
            Button { app.play(current, episode: episode) } label: {
                HStack(spacing: 12) {
                    Image(systemName: episode.isWatched ? "checkmark.circle.fill" : "play.circle").font(.title2).foregroundStyle(episode.isWatched ? .green : Design.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(episode.title).font(.headline)
                        Text("Episodio \(episode.number.formatted())\(episode.progress > 0 ? " · \(Int(episode.progress)/60) min visti" : "")").font(.caption).foregroundStyle(.secondary)
                        if episode.duration > 0 && episode.progress > 0 { ProgressView(value: min(episode.progress/episode.duration, 1)).accessibilityLabel("Progresso episodio") }
                    }; Spacer()
                }.padding(.vertical, 12).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if downloads.localURL(for: episode.id) != nil { Image(systemName: "arrow.down.circle.fill").foregroundStyle(.green).accessibilityLabel("Disponibile offline") }
            Menu {
                Button(episode.isWatched ? "Segna come non visto" : "Segna come visto") { store.toggleWatched(episode) }
                Button("Scarica episodio") { downloads.enqueue(anime: current, episode: episode) }
            } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Azioni \(episode.title)")
        }
    }
}
