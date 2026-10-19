import SwiftUI

@MainActor struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var app: AppContainer
    @State private var deleting: String?
    var body: some View {
        Group {
            if downloads.records.isEmpty { EmptyState(title: "La tua videoteca offline", message: "Dal dettaglio di un'opera, apri le azioni di un episodio e scegli Scarica.", symbol: "arrow.down.circle") }
            else {
                List {
                    ForEach(downloads.records) { record in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(record.anime.title).font(.headline)
                            Text(record.episode.title).font(.subheadline).foregroundStyle(.secondary)
                            Label(record.state.label, systemImage: symbol(record.state)).font(.caption)
                            if record.state == .downloading { ProgressView(value: record.fraction).accessibilityLabel("Download \(Int(record.fraction*100)) percento") }
                            if let error = record.error { Text(error).font(.caption).foregroundStyle(.red) }
                            HStack {
                                if record.state == .completed {
                                    Button("Riproduci offline") { app.play(record.anime, episode: record.episode) }.disabled(downloads.localURL(for: record.id) == nil)
                                }
                                if [.failed, .cancelled].contains(record.state) { Button("Riprova") { downloads.retry(record.id) } }
                                if [.queued, .downloading].contains(record.state) { Button("Annulla", role: .cancel) { downloads.cancel(record.id) } }
                                Spacer()
                                IconButton(title: "Elimina download", symbol: "trash") { deleting = record.id }
                            }.buttonStyle(.borderless)
                        }.padding(.vertical, 8)
                    }
                }
            }
        }.navigationTitle("Download")
        .confirmationDialog("Eliminare il video scaricato?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) { Button("Elimina dal dispositivo", role: .destructive) { if let id = deleting { downloads.remove(id) }; deleting = nil } }
        .alert("Download", isPresented: Binding(get: { downloads.lastError != nil }, set: { if !$0 { downloads.lastError = nil } })) { Button("OK") { downloads.lastError = nil } } message: { Text(downloads.lastError ?? "") }
    }
    private func symbol(_ state: DownloadState) -> String {
        switch state { case .queued: return "clock"; case .downloading: return "arrow.down.circle"; case .completed: return "checkmark.circle.fill"; case .failed: return "exclamationmark.triangle"; case .cancelled: return "xmark.circle" }
    }
}
