import SwiftUI

@MainActor struct RootView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var store: LocalStore
    @Environment(\.scenePhase) private var phase
    var body: some View {
        TabView {
            NavigationStack { LibraryView() }.tabItem { Label("Libreria", systemImage: "rectangle.stack.fill") }
            NavigationStack { SearchView() }.tabItem { Label("Cerca", systemImage: "magnifyingglass") }
            NavigationStack { BrowseView() }.tabItem { Label("Esplora", systemImage: "globe") }
            NavigationStack { DownloadsView() }.tabItem { Label("Download", systemImage: "arrow.down.circle.fill") }
            NavigationStack { SettingsView() }.tabItem { Label("Impostazioni", systemImage: "gearshape.fill") }
        }
        .tint(Design.accent).preferredColorScheme(store.preferences.darkMode ? .dark : .light)
        .modifier(PlayerPresentation(route: $container.playback))
        .onChange(of: phase) { _, new in if new != .active { container.player.persist() } }
        .alert("Salvataggio non riuscito", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) { Button("OK") { store.lastError = nil } } message: { Text(store.lastError ?? "") }
    }
}
@MainActor private struct PlayerPresentation: ViewModifier {
    @Binding var route: PlaybackRoute?
    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(item: $route) { route in PlayerView(route: route) }
        #else
        content.sheet(item: $route) { route in PlayerView(route: route).frame(minWidth: 720, minHeight: 460) }
        #endif
    }
}
