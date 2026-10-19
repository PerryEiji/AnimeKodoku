import Foundation
import AVFoundation
import CryptoKit
import Combine

private enum DownloadEvent: Sendable {
    case progress(String, Double)
    case saved(String, URL)
    case finished(String, String?)
    case drained(String)
}
private enum DownloadPaths {
    static var home: URL { URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true) }
    static func relative(_ url: URL) throws -> String {
        let prefix = home.standardizedFileURL.path + "/"
        guard url.standardizedFileURL.path.hasPrefix(prefix) else { throw AppError.message("Percorso download non valido.") }
        return String(url.standardizedFileURL.path.dropFirst(prefix.count))
    }
    static func resolve(_ path: String) -> URL? {
        let url = home.appendingPathComponent(path).standardizedFileURL
        guard url.path.hasPrefix(home.standardizedFileURL.path + "/") else { return nil }
        return url
    }
    static func destination(_ id: String, ext: String) throws -> URL {
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Offline", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name).appendingPathExtension(ext)
    }
}

// Delegate is deliberately not MainActor isolated: move temporary files before
// returning from URLSession's callback. Only immutable events cross to the UI.
private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, AVAssetDownloadDelegate, @unchecked Sendable {
    var event: ((DownloadEvent) -> Void)?
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription else { return }
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw AppError.message("Il server ha rifiutato il download.") }
            let mime = response.mimeType?.lowercased() ?? ""
            guard mime != "text/html", mime != "application/json" else { throw AppError.message("Il server non ha restituito un video.") }
            let target = try DownloadPaths.destination(id, ext: "mp4")
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            try FileManager.default.moveItem(at: location, to: target)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            var targetCopy = target; try targetCopy.setResourceValues(values)
            event?(.saved(id, target))
        } catch { event?(.finished(id, error.localizedDescription)) }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }
        event?(.progress(id, Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)))
    }
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = assetDownloadTask.taskDescription else { return }
        event?(.saved(id, location)) // System-managed HLS package; do not move it.
    }
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        guard let id = assetDownloadTask.taskDescription else { return }
        let expected = timeRangeExpectedToLoad.duration.seconds
        let loaded = loadedTimeRanges.reduce(0.0) { $0 + $1.timeRangeValue.duration.seconds }
        if expected.isFinite && expected > 0 { event?(.progress(id, min(loaded/expected, 1))) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription else { return }; event?(.finished(id, error?.localizedDescription))
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        if let id = session.configuration.identifier { event?(.drained(id)) }
    }
}

@MainActor final class DownloadManager: ObservableObject {
    static let fileIdentifier = "org.animekodoku.files.v1"
    static let hlsIdentifier = "org.animekodoku.hls.v1"
    @Published private(set) var records: [DownloadRecord]
    @Published var lastError: String?
    private let store: LocalStore
    private let delegate: DownloadDelegate
    private var files: URLSession!
    private var hls: AVAssetDownloadURLSession!
    private var tasks: [String: URLSessionTask] = [:]
    private var finishedIDs: Set<String> = []
    private var completions: [String: () -> Void] = [:]
    private var drainedSessions: Set<String> = []
    private var reconciling = true
    init(store: LocalStore) throws {
        self.store = store
        self.records = try store.read("downloads") ?? []
        self.delegate = DownloadDelegate()
        delegate.event = { [weak self] event in
            DispatchQueue.main.async { self?.receive(event) }
        }
        let config = URLSessionConfiguration.background(withIdentifier: Self.fileIdentifier)
        config.isDiscretionary = false; config.allowsCellularAccess = store.preferences.cellularDownloads
        #if os(iOS)
        config.sessionSendsLaunchEvents = true
        #endif
        files = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let assetConfig = URLSessionConfiguration.background(withIdentifier: Self.hlsIdentifier)
        #if os(iOS)
        assetConfig.sessionSendsLaunchEvents = true
        #endif
        assetConfig.isDiscretionary = false
        assetConfig.allowsCellularAccess = store.preferences.cellularDownloads
        hls = AVAssetDownloadURLSession(configuration: assetConfig, assetDownloadDelegate: delegate, delegateQueue: nil)
        Task { await reconcile() }
    }
    func handleBackgroundEvents(identifier: String, completion: @escaping () -> Void) {
        guard [Self.fileIdentifier, Self.hlsIdentifier].contains(identifier) else { completion(); return }
        if drainedSessions.remove(identifier) != nil { completion() }
        else { completions[identifier] = completion }
    }
    private func reconcile() async {
        var active = await files.allTasks
        active += await hls.allTasks
        for task in active {
            if let token = task.taskDescription, let id = records.first(where: { $0.attemptID == token })?.id {
                tasks[id] = task
                if let index = records.firstIndex(where: { $0.id == id }) { records[index].state = .downloading }
                if task.state == .suspended { task.resume() }
            } else { task.cancel() }
        }
        for i in records.indices where records[i].state == .downloading && tasks[records[i].id] == nil {
            // A file/package alone cannot prove completion; never expose partial assets.
            records[i].state = .failed; records[i].error = "Download interrotto. Tocca Riprova."
        }
        for i in records.indices where records[i].state == .completed {
            let exists = records[i].relativePath.flatMap(DownloadPaths.resolve).map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            if !exists { records[i].state = .failed; records[i].error = "File offline non più disponibile. Scarica nuovamente l'episodio." }
        }
        reconciling = false; persist(); pump()
    }
    func enqueue(anime: Anime, episode: Episode) {
        guard !records.contains(where: { $0.id == episode.id && [.queued, .downloading, .completed].contains($0.state) }) else { return }
        if let i = records.firstIndex(where: { $0.id == episode.id }) { records.remove(at: i) }
        records.append(DownloadRecord(anime: anime, episode: episode)); persist(); pump()
    }
    func retry(_ id: String) {
        guard let i = records.firstIndex(where: { $0.id == id }), [.failed, .cancelled].contains(records[i].state) else { return }
        if let path = records[i].relativePath, let url = DownloadPaths.resolve(path) { try? FileManager.default.removeItem(at: url) }
        records[i].state = .queued; records[i].error = nil; records[i].fraction = 0; records[i].relativePath = nil; records[i].attemptID = nil; finishedIDs.remove(id); persist(); pump()
    }
    func cancel(_ id: String) {
        tasks[id]?.cancel(); tasks[id] = nil
        if let i = records.firstIndex(where: { $0.id == id }), records[i].state != .completed { records[i].state = .cancelled; records[i].error = nil }
        persist(); pump()
    }
    func remove(_ id: String) {
        tasks[id]?.cancel(); tasks[id] = nil
        if let record = records.first(where: { $0.id == id }) {
            for path in [record.relativePath, record.subtitlePath].compactMap({ $0 }) {
                if let url = DownloadPaths.resolve(path) { do { try FileManager.default.removeItem(at: url) } catch { lastError = error.localizedDescription } }
            }
        }
        records.removeAll { $0.id == id }; finishedIDs.remove(id); persist(); pump()
    }
    func localURL(for episodeID: String) -> URL? {
        guard let item = records.first(where: { $0.id == episodeID && $0.state == .completed }), let path = item.relativePath, let url = DownloadPaths.resolve(path), FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    func subtitleURL(for episodeID: String) -> URL? {
        guard let path = records.first(where: { $0.id == episodeID })?.subtitlePath else { return nil }
        return DownloadPaths.resolve(path)
    }
    private func pump() {
        guard !reconciling, tasks.isEmpty, let i = records.firstIndex(where: { $0.state == .queued }) else { return }
        let record = records[i]
        guard let url = record.episode.videoUrl, url.scheme == "https" else {
            records[i].state = .failed; records[i].error = "Video HTTPS non disponibile."; persist(); pump(); return
        }
        let task: URLSessionTask?
        if url.pathExtension.lowercased() == "m3u8" {
            task = hls.makeAssetDownloadTask(asset: AVURLAsset(url: url), assetTitle: record.anime.title, assetArtworkData: nil, options: nil)
        } else if url.pathExtension.lowercased() == "mp4" {
            task = files.downloadTask(with: url)
        } else { task = nil }
        guard let task else {
            records[i].state = .failed
            records[i].error = "Formato non scaricabile. Usa un URL MP4 o M3U8 scaricabile, senza DRM."
            persist(); pump(); return
        }
        let attemptID = record.id + "|" + UUID().uuidString
        records[i].attemptID = attemptID
        task.taskDescription = attemptID
        tasks[record.id] = task; records[i].state = .downloading; persist(); task.resume()
    }
    private func receive(_ event: DownloadEvent) {
        switch event {
        case .drained(let id):
            persist()
            if let completion = completions.removeValue(forKey: id) { completion() } else { drainedSessions.insert(id) }
        case .progress(let token, let value):
            guard let id = records.first(where: { $0.attemptID == token })?.id else { return }
            guard let i = records.firstIndex(where: { $0.id == id && $0.state == .downloading }) else { return }
            let shouldSave = Date().timeIntervalSince(records[i].updatedAt) >= 1 || abs(records[i].fraction - value) >= 0.02
            records[i].fraction = max(0, min(value, 1)); if shouldSave { records[i].updatedAt = Date(); persist() }
        case .saved(let token, let url):
            guard let id = records.first(where: { $0.attemptID == token })?.id,
                  let i = records.firstIndex(where: { $0.id == id && $0.state == .downloading }) else {
                if (try? DownloadPaths.relative(url)) != nil { try? FileManager.default.removeItem(at: url) }; return
            }
            do { records[i].relativePath = try DownloadPaths.relative(url); persist(); completeIfReady(id) }
            catch { receive(.finished(token, error.localizedDescription)) }
        case .finished(let token, let error):
            guard let id = records.first(where: { $0.attemptID == token })?.id else { return }
            guard let i = records.firstIndex(where: { $0.id == id && $0.state == .downloading }) else { return }
            if let error {
                records[i].state = .failed; records[i].error = error; tasks[id] = nil; persist(); pump()
            } else { finishedIDs.insert(id); completeIfReady(id) }
        }
    }
    private func completeIfReady(_ id: String) {
        guard finishedIDs.contains(id), let i = records.firstIndex(where: { $0.id == id }), records[i].relativePath != nil else { return }
        records[i].state = .completed; records[i].fraction = 1; records[i].error = nil
        tasks[id] = nil; finishedIDs.remove(id); persist(); pump()
        let record = records[i]
        if let url = record.episode.subtitleUrl {
            Task {
                do {
                    let data = try await NetworkClient.shared.data(from: url)
                    let ext = url.pathExtension.lowercased()
                    guard ["srt", "ass", "ssa"].contains(ext) else { return }
                    let target = try DownloadPaths.destination(id + ":sub", ext: ext)
                    try data.write(to: target, options: .atomic)
                    if let j = records.firstIndex(where: { $0.id == id && $0.state == .completed }) { records[j].subtitlePath = try DownloadPaths.relative(target); persist() }
                } catch { lastError = "Video salvato; sottotitoli non scaricati: \(error.localizedDescription)" }
            }
        }
    }
    private func persist() { do { try store.write(records, key: "downloads") } catch { lastError = error.localizedDescription } }
}
