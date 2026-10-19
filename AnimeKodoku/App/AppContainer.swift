import SwiftUI
import Combine

struct PlaybackRoute: Identifiable {
    var id: String { episode.id }
    let anime: Anime
    let episode: Episode
}
@MainActor final class AppContainer: ObservableObject {
    let store: LocalStore
    let sources: SourceRegistry
    let downloads: DownloadManager
    let player: PlayerSession
    @Published var playback: PlaybackRoute?
    init() throws {
        URLCache.shared = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 128 * 1024 * 1024, diskPath: "AnimeKodokuImages")
        let store = try LocalStore()
        self.store = store; sources = try SourceRegistry(store: store)
        downloads = try DownloadManager(store: store)
        player = PlayerSession(store: store, downloads: downloads)
    }
    func play(_ anime: Anime, episode: Episode) { playback = PlaybackRoute(anime: anime, episode: episode) }
}
@MainActor final class Bootstrap: ObservableObject {
    @Published var container: AppContainer?
    @Published var error: String?
    init() { retry() }
    func retry() {
        do {
            let app = try AppContainer(); container = app; error = nil
            #if os(iOS)
            AppDelegate.connect(app.downloads)
            #endif
        }
        catch { self.error = error.localizedDescription }
    }
}
