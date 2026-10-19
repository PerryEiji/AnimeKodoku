import Foundation

public enum AnimeStatus: String, Codable, Hashable, CaseIterable, Sendable {
    case airing, finished, upcoming, unknown
}
public enum WatchStatus: String, Codable, Hashable, CaseIterable, Identifiable, Sendable {
    case planning, watching, completed, onHold, dropped
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .planning: return "Da vedere"
        case .watching: return "In corso"
        case .completed: return "Completati"
        case .onHold: return "In pausa"
        case .dropped: return "Abbandonati"
        }
    }
}
public struct Anime: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var sourceId: String
    public var title: String
    public var coverUrl: URL?
    public var bannerUrl: URL?
    public var description: String
    public var status: AnimeStatus
    public var tags: [String]
    public init(id: String, sourceId: String, title: String, coverUrl: URL? = nil, bannerUrl: URL? = nil, description: String, status: AnimeStatus = .unknown, tags: [String] = []) {
        self.id = id; self.sourceId = sourceId; self.title = title
        self.coverUrl = coverUrl; self.bannerUrl = bannerUrl; self.description = description
        self.status = status; self.tags = tags
    }
}
public struct Episode: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var animeId: String
    public var number: Double
    public var title: String
    public var videoUrl: URL?
    public var subtitleUrl: URL?
    public var duration: Double
    public var isWatched: Bool
    public var progress: Double
    public init(id: String, animeId: String, number: Double, title: String, videoUrl: URL? = nil, subtitleUrl: URL? = nil, duration: Double = 0, isWatched: Bool = false, progress: Double = 0) {
        self.id = id; self.animeId = animeId; self.number = number; self.title = title
        self.videoUrl = videoUrl; self.subtitleUrl = subtitleUrl; self.duration = duration
        self.isWatched = isWatched; self.progress = progress
    }
}
public struct Source: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var baseUrl: URL
    public var language: String
    public var isEnabled: Bool
    public var supportsSearch: Bool
    public init(id: String, name: String, baseUrl: URL, language: String, isEnabled: Bool = true, supportsSearch: Bool = true) {
        self.id = id; self.name = name; self.baseUrl = baseUrl; self.language = language
        self.isEnabled = isEnabled; self.supportsSearch = supportsSearch
    }
}
public struct LibraryEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: String { animeId }
    public var animeId: String
    public var status: WatchStatus
    public var lastEpisodeId: String?
    public var lastProgress: Double
    public var addedAt: Date
    public init(animeId: String, status: WatchStatus = .planning, lastEpisodeId: String? = nil, lastProgress: Double = 0, addedAt: Date = Date()) {
        self.animeId = animeId; self.status = status; self.lastEpisodeId = lastEpisodeId
        self.lastProgress = lastProgress; self.addedAt = addedAt
    }
}
public struct Filter: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var value: String
    public init(id: String, value: String) { self.id = id; self.value = value }
}
public struct FilterDefinition: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var options: [String]
    public init(id: String, title: String, options: [String]) { self.id = id; self.title = title; self.options = options }
}
public struct LibraryFilter: Codable, Hashable, Sendable {
    public var status: WatchStatus?
    public var sourceId: String?
    public var tag: String?
    public init(status: WatchStatus? = nil, sourceId: String? = nil, tag: String? = nil) { self.status = status; self.sourceId = sourceId; self.tag = tag }
    public func matches(_ anime: Anime, entry: LibraryEntry) -> Bool {
        (status == nil || entry.status == status) && (sourceId == nil || anime.sourceId == sourceId) && (tag == nil || anime.tags.contains(tag!))
    }
}
public struct SavedGroup: Identifiable, Codable, Hashable, Sendable {
    public var id = UUID()
    public var name: String
    public var filter: LibraryFilter
}
public struct Preferences: Codable, Hashable, Sendable {
    public var darkMode = true
    public var listMode = false
    public var libraryFilter = LibraryFilter()
    public var groups: [SavedGroup] = []
    public var searchHistory: [String] = []
    public var sourceFilters: [String: [Filter]] = [:]
    public var disabledSourceIds: Set<String> = []
    public var cellularDownloads = false
    public var playbackRate: Float = 1
    public var incognito = false
    public var subtitleScale = 1.0
    public init() {}
}
public enum DownloadState: String, Codable, Hashable, Sendable {
    case queued, downloading, completed, failed, cancelled
    public var label: String {
        switch self {
        case .queued: return "In coda"
        case .downloading: return "In download"
        case .completed: return "Completato"
        case .failed: return "Errore"
        case .cancelled: return "Annullato"
        }
    }
}
public struct DownloadRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: String { episode.id }
    public var anime: Anime
    public var episode: Episode
    public var state: DownloadState = .queued
    public var fraction: Double = 0
    // Path relative to the app sandbox, resilient to container relocation.
    public var relativePath: String?
    public var subtitlePath: String?
    public var error: String?
    public var updatedAt = Date()
    public var attemptID: String?
}
public struct SourceManifest: Identifiable, Codable, Hashable, Sendable {
    public var id: String { source.id }
    public var version: Int
    public var kind: String
    public var source: Source
    public var filters: [FilterDefinition]
}
public struct Backup: Codable, Sendable {
    public var version: Int
    public var createdAt: Date
    public var library: [LibraryEntry]
    public var anime: [Anime]
    public var episodes: [Episode]
    public var preferences: Preferences
}
public enum AppError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
