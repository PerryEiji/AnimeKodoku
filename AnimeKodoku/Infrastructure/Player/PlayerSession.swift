import Foundation
import AVFoundation
import Combine
#if os(iOS)
import AVFAudio
import MediaPlayer
#endif

@MainActor final class PlayerSession: ObservableObject {
    let player = AVPlayer()
    @Published var seconds = 0.0
    @Published var duration = 0.0
    @Published var isPlaying = false
    @Published var loading = false
    @Published var error: String?
    @Published var subtitleText = ""
    @Published var subtitleError: String?
    @Published var captionsEnabled = true
    @Published var zoom = false
    private let store: LocalStore
    private let downloads: DownloadManager
    private var episode: Episode?
    private var anime: Anime?
    private var cues: [SubtitleCue] = []
    private var timeObserver: Any?
    private var itemObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var audioObservers: [NSObjectProtocol] = []
    private var lastSave = Date.distantPast
    private var generation = UUID()
    private var loadingTask: Task<Void, Never>?
    #if os(iOS)
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    #endif
    init(store: LocalStore, downloads: DownloadManager) { self.store = store; self.downloads = downloads }
    func open(anime: Anime, episode: Episode) {
        stop()
        self.anime = anime; self.episode = episode; loading = true
        let token = UUID(); generation = token
        guard let url = downloads.localURL(for: episode.id) ?? episode.videoUrl else {
            loading = false; error = "Nessun video configurato. Imposta DEMO_VIDEO_URL o aggiungi una fonte REST."; return
        }
        guard url.isFileURL || url.scheme == "https" else { loading = false; error = "URL video non supportato."; return }
        loadingTask = Task { [weak self] in
            guard let self else { return }
            do {
                #if os(iOS)
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                try AVAudioSession.sharedInstance().setActive(true)
                player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
                #endif
                let asset = AVURLAsset(url: url)
                guard try await asset.load(.isPlayable) else { throw AppError.message("Video non riproducibile su questo dispositivo.") }
                try Task.checkCancellation(); guard generation == token else { return }
                let item = AVPlayerItem(asset: asset)
                player.replaceCurrentItem(with: item)
                itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                    let failed = item.status == .failed
                    let message = item.error?.localizedDescription
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token else { return }
                        if failed { self.loading = false; self.error = message ?? "Riproduzione interrotta."; self.isPlaying = false }
                    }
                }
                let saved = store.episodes.first(where: { $0.id == episode.id }) ?? episode
                let resume = saved.isWatched ? 0 : max(0, saved.progress)
                if resume > 0 { await player.seek(to: CMTime(seconds: resume, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) }
                try Task.checkCancellation(); guard generation == token else { return }
                observeTime(token: token)
                endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in guard let self, self.generation == token else { return }; self.seconds = self.duration; self.isPlaying = false; self.persist() }
                }
                loading = false; play()
                #if os(iOS)
                configureRemoteControls(); observeAudioSession()
                #endif
                if let subtitle = downloads.subtitleURL(for: episode.id) ?? episode.subtitleUrl {
                    do { try await loadSubtitles(url: subtitle, token: token) }
                    catch { if generation == token { subtitleError = error.localizedDescription } }
                }
            } catch is CancellationError { }
            catch { if generation == token { loading = false; self.error = error.localizedDescription } }
        }
    }
    private func observeTime(token: UUID) {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if time.seconds.isFinite { self.seconds = max(0, time.seconds) }
                let length = self.player.currentItem?.duration.seconds ?? 0
                self.duration = length.isFinite ? max(0, length) : 0
                self.isPlaying = self.player.rate != 0
                self.subtitleText = self.captionsEnabled ? SubtitleParser.activeText(at: self.seconds, cues: self.cues) : ""
                if Date().timeIntervalSince(self.lastSave) >= 5 { self.persist() }
            }
        }
    }
    func play() { player.playImmediately(atRate: store.preferences.playbackRate); isPlaying = true; updateNowPlaying() }
    func pause() { player.pause(); isPlaying = false; persist(); updateNowPlaying() }
    func toggle() { if isPlaying { pause() } else { play() } }
    func seek(by offset: Double) { seek(to: seconds + offset) }
    func seek(to value: Double) {
        guard value.isFinite else { return }
        let target = max(0, duration > 0 ? min(value, duration) : value)
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        seconds = target
    }
    func setRate(_ value: Float) { store.preferences.playbackRate = value; if isPlaying { player.rate = value }; updateNowPlaying() }
    func loadExternalSubtitles(_ url: URL) async {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { try await loadSubtitles(url: url, token: generation); subtitleError = nil }
        catch { subtitleError = error.localizedDescription }
    }
    private func loadSubtitles(url: URL, token: UUID) async throws {
        let data: Data
        if url.isFileURL {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 5 * 1024 * 1024 else { throw AppError.message("Sottotitoli troppo grandi (massimo 5 MB).") }
            data = try Data(contentsOf: url)
        } else { data = try await NetworkClient.shared.data(from: url) }
        guard data.count <= 5 * 1024 * 1024, let text = String(data: data, encoding: .utf8) else { throw AppError.message("Usa un file sottotitoli UTF-8 inferiore a 5 MB.") }
        let ext = url.pathExtension
        let parsed = try await Task.detached(priority: .userInitiated) { try SubtitleParser.parse(text, extension: ext) }.value
        guard generation == token else { return }; cues = parsed
    }
    func persist() {
        guard let episode else { return }
        store.saveProgress(episode: episode, seconds: seconds, duration: duration)
        lastSave = Date(); updateNowPlaying()
    }
    func stop() {
        persist(); generation = UUID(); loadingTask?.cancel(); loadingTask = nil
        player.pause()
        if let observer = timeObserver { player.removeTimeObserver(observer); timeObserver = nil }
        itemObservation?.invalidate(); itemObservation = nil
        if let observer = endObserver { NotificationCenter.default.removeObserver(observer); endObserver = nil }
        for observer in audioObservers { NotificationCenter.default.removeObserver(observer) }; audioObservers = []
        player.replaceCurrentItem(with: nil)
        #if os(iOS)
        for (command, target) in remoteTargets { command.removeTarget(target) }; remoteTargets = []
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        episode = nil; anime = nil; cues = []; subtitleText = ""; subtitleError = nil
        seconds = 0; duration = 0; isPlaying = false; loading = false; error = nil
    }
    private func updateNowPlaying() {
        #if os(iOS)
        guard let anime, let episode else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: anime.title, MPMediaItemPropertyAlbumTitle: episode.title, MPMediaItemPropertyPlaybackDuration: duration, MPNowPlayingInfoPropertyElapsedPlaybackTime: seconds, MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? player.rate : 0]
        #endif
    }
    #if os(iOS)
    private func configureRemoteControls() {
        let center = MPRemoteCommandCenter.shared()
        let play = center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.play() }; return .success }
        let pause = center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        center.skipForwardCommand.preferredIntervals = [10]; center.skipBackwardCommand.preferredIntervals = [10]
        let next = center.skipForwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.seek(by: 10) }; return .success }
        let previous = center.skipBackwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.seek(by: -10) }; return .success }
        let position = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let value = event.positionTime; Task { @MainActor in self?.seek(to: value) }; return .success
        }
        remoteTargets = [(center.playCommand, play), (center.pauseCommand, pause), (center.skipForwardCommand, next), (center.skipBackwardCommand, previous), (center.changePlaybackPositionCommand, position)]
    }
    private func observeAudioSession() {
        let interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(rawValue: note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor [weak self] in if type == .began { self?.pause() } else if options.contains(.shouldResume) { self?.play() } }
        }
        let route = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let reason = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { Task { @MainActor in self?.pause() } }
        }
        audioObservers = [interruption, route]
    }
    #endif
}
