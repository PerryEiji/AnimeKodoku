import SwiftUI
import UniformTypeIdentifiers

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
@MainActor struct SettingsView: View {
    @EnvironmentObject private var store: LocalStore
    @State private var exporting = false
    @State private var importing = false
    @State private var document = BackupDocument(data: Data())
    @State private var pendingRestore: Data?
    @State private var confirmRestore = false
    @State private var message: String?
    var body: some View {
        Form {
            Section("Aspetto") {
                Toggle("Tema scuro", isOn: $store.preferences.darkMode)
                Toggle("Libreria in lista", isOn: $store.preferences.listMode)
            }
            Section("Lettore") {
                Picker("Velocità predefinita", selection: $store.preferences.playbackRate) { ForEach([Float(0.5), 0.75, 1, 1.25, 1.5, 2], id: \.self) { Text("\($0.formatted())×").tag($0) } }
                Toggle("Incognito", isOn: $store.preferences.incognito)
                Text("In incognito non vengono salvati progressi o cronologia di visione.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Consenti rete cellulare", isOn: $store.preferences.cellularDownloads)
                Text("La modifica si applica alle sessioni di download al prossimo avvio dell'app. I download sono conservati sul dispositivo, esclusi dai backup di sistema quando gestiti dall'app.").font(.caption).foregroundStyle(.secondary)
            } header: { Text("Download") }
            Section("Tracker") {
                NavigationLink("AniList") { trackerInfo("AniList") }
                NavigationLink("MyAnimeList") { trackerInfo("MyAnimeList") }
            }
            Section("Dati") {
                Button("Esporta backup JSON") { do { document = BackupDocument(data: try store.backupData()); exporting = true } catch { message = error.localizedDescription } }
                Button("Ripristina backup…") { importing = true }
                Text("Il backup contiene libreria, metadati, progressi, filtri e preferenze. Non include video, credenziali o manifest REST installati.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Informazioni") {
                LabeledContent("AnimeKodoku", value: "1.0.0")
                Text("Client open source per contenuti da fonti esterne. Nessun contenuto anime incluso. SwiftUI · SwiftData · AVFoundation.").font(.subheadline).foregroundStyle(.secondary)
                Text("Ispirazione UX: Aidoku. Implementazione indipendente; nessun codice Aidoku copiato.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped).navigationTitle("Impostazioni")
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "AnimeKodoku-backup") { result in if case .failure(let error) = result { message = error.localizedDescription } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size < 50 * 1024 * 1024 else { throw AppError.message("Backup troppo grande.") }
                pendingRestore = try Data(contentsOf: url); confirmRestore = true
            } catch { message = error.localizedDescription }
        }
        .confirmationDialog("Sostituire libreria, progressi e preferenze con il backup?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Ripristina", role: .destructive) { if let data = pendingRestore { do { try store.restore(data); message = "Backup ripristinato." } catch { message = error.localizedDescription } }; pendingRestore = nil }
            Button("Annulla", role: .cancel) { pendingRestore = nil }
        }
        .alert("Dati", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { message = nil } } message: { Text(message ?? "") }
    }
    private func trackerInfo(_ name: String) -> some View {
        EmptyState(title: name, message: "Integrazione predisposta, non collegata. Per attivarla servono registrazione OAuth, redirect URI, credenziali in Keychain e un mapping verificato degli ID delle opere. Il progresso resta locale.", symbol: "person.crop.circle.badge.clock").navigationTitle(name)
    }
}
