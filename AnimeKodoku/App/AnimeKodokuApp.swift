import SwiftUI
#if os(iOS)
import UIKit

@MainActor final class AppDelegate: NSObject, UIApplicationDelegate {
    static weak var downloads: DownloadManager?
    private static var pending: [(String, () -> Void)] = []
    static func connect(_ manager: DownloadManager) {
        downloads = manager
        for (id, completion) in pending { manager.handleBackgroundEvents(identifier: id, completion: completion) }
        pending = []
    }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if let manager = Self.downloads { manager.handleBackgroundEvents(identifier: identifier, completion: completionHandler) }
        else { Self.pending.append((identifier, completionHandler)) }
    }
}
#endif

@main @MainActor struct AnimeKodokuApp: App {
    @StateObject private var bootstrap = Bootstrap()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    #endif
    var body: some Scene {
        WindowGroup {
            if let container = bootstrap.container {
                RootView()
                    .environmentObject(container)
                    .environmentObject(container.store)
                    .environmentObject(container.sources)
                    .environmentObject(container.downloads)
                    .environmentObject(container.player)
                    .onAppear {
                        #if os(iOS)
                        AppDelegate.connect(container.downloads)
                        #endif
                    }
            } else { ErrorState(message: "Impossibile aprire i dati locali: \(bootstrap.error ?? "Errore sconosciuto")", retry: bootstrap.retry) }
        }
    }
}
