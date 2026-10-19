import Foundation
import SwiftData
import Combine

@Model final class StoredRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(key: String, payload: Data) { self.key = key; self.payload = payload }
}

@MainActor final class LocalStore: ObservableObject {
    let container: ModelContainer
    private let context: ModelContext
    @Published private(set) var library: [LibraryEntry] = []
    @Published private(set) var anime: [Anime] = []
    @Published private(set) var episodes: [Episode] = []
    @Published var preferences = Preferences() { didSet { persistPreferences() } }
    @Published var lastError: String?
    private var records: [String: StoredRecord] = [:]
    init(inMemory: Bool = false) throws {
        let schema = Schema([StoredRecord.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)])
        context = ModelContext(container); context.autosaveEnabled = false
        for record in try context.fetch(FetchDescriptor<StoredRecord>()) { records[record.key] = record }
        library = try read("library") ?? []
        anime = try read("anime") ?? []
        episodes = try read("episodes") ?? []
        preferences = try read("preferences") ?? Preferences()
    }
    func read<T: Decodable>(_ key: String) throws -> T? {
        guard let record = records[key] else { return nil }
        return try JSONDecoder().decode(T.self, from: record.payload)
    }
    func write<T: Encodable>(_ value: T, key: String) throws {
        try stage(value, key: key); try context.save()
    }
    private func stage<T: Encodable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        if let record = records[key] { record.payload = data }
        else { let record = StoredRecord(key: key, payload: data); context.insert(record); records[key] = record }
    }
    private func persistPreferences() { do { try write(preferences, key: "preferences") } catch { lastError = error.localizedDescription } }
    private func saveContent() {
        do {
            try stage(library, key: "library"); try stage(anime, key: "anime"); try stage(episodes, key: "episodes"); try context.save()
        } catch { lastError = error.localizedDescription }
    }
    func cache(_ values: [Anime]) {
        for value in values { if let i = anime.firstIndex(where: { $0.id == value.id }) { anime[i] = value } else { anime.append(value) } }
        saveContent()
    }
    func cacheEpisodes(_ values: [Episode]) {
        for var value in values {
            if let i = episodes.firstIndex(where: { $0.id == value.id }) {
                value.progress = episodes[i].progress; value.isWatched = episodes[i].isWatched
                episodes[i] = value
            } else { episodes.append(value) }
        }
        saveContent()
    }
    func add(_ value: Anime) { cache([value]); guard !library.contains(where: { $0.animeId == value.id }) else { return }; library.append(LibraryEntry(animeId: value.id)); saveContent() }
    func remove(ids: Set<String>) { library.removeAll { ids.contains($0.animeId) }; saveContent() }
    func setStatus(_ status: WatchStatus, ids: Set<String>) { for i in library.indices where ids.contains(library[i].animeId) { library[i].status = status }; saveContent() }
    func saveProgress(episode: Episode, seconds: Double, duration: Double) {
        guard !preferences.incognito, seconds.isFinite, seconds >= 0 else { return }
        if let i = episodes.firstIndex(where: { $0.id == episode.id }) {
            episodes[i].progress = seconds
            if duration.isFinite && duration > 0 { episodes[i].duration = duration; if seconds / duration >= 0.9 { episodes[i].isWatched = true } }
        } else { var value = episode; value.progress = seconds; if duration.isFinite && duration > 0 { value.duration = duration; value.isWatched = seconds / duration >= 0.9 }; episodes.append(value) }
        if let i = library.firstIndex(where: { $0.animeId == episode.animeId }) {
            library[i].lastEpisodeId = episode.id; library[i].lastProgress = seconds
            if library[i].status == .planning { library[i].status = .watching }
        }
        saveContent()
    }
    func toggleWatched(_ episode: Episode) {
        if let i = episodes.firstIndex(where: { $0.id == episode.id }) { episodes[i].isWatched.toggle(); if !episodes[i].isWatched { episodes[i].progress = 0 } }; saveContent()
    }
    func backupData() throws -> Data {
        let backup = Backup(version: 1, createdAt: Date(), library: library, anime: anime, episodes: episodes, preferences: preferences)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }
    func restore(_ data: Data) throws {
        guard data.count < 50 * 1024 * 1024 else { throw AppError.message("Backup troppo grande.") }
        let value = try JSONDecoder().decode(Backup.self, from: data)
        guard value.version == 1, Set(value.anime.map(\.id)).count == value.anime.count,
              Set(value.library.map(\.id)).count == value.library.count,
              Set(value.episodes.map(\.id)).count == value.episodes.count,
              value.library.allSatisfy({ item in value.anime.contains { $0.id == item.animeId } }) else { throw AppError.message("Backup non valido o versione incompatibile.") }
        // Stage everything and commit once; publish only after successful disk write.
        do {
            try stage(value.library, key: "library"); try stage(value.anime, key: "anime")
            try stage(value.episodes, key: "episodes"); try stage(value.preferences, key: "preferences"); try context.save()
        } catch { context.rollback(); records = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StoredRecord>()).map { ($0.key, $0) }); throw error }
        library = value.library; anime = value.anime; episodes = value.episodes; preferences = value.preferences
    }
}
