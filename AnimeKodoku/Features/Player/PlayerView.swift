import SwiftUI
import UniformTypeIdentifiers

@MainActor struct PlayerView: View {
    let route: PlaybackRoute
    @EnvironmentObject private var session: PlayerSession
    @EnvironmentObject private var store: LocalStore
    @EnvironmentObject private var app: AppContainer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var controls = true
    @State private var importing = false
    @State private var hideTask: Task<Void, Never>?
    private var nextEpisode: Episode? { store.episodes.filter { $0.animeId == route.anime.id && $0.number > route.episode.number }.min { $0.number < $1.number } }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                PlayerSurface(player: phase == .background ? nil : session.player, zoom: session.zoom)
                    .ignoresSafeArea().contentShape(Rectangle())
                    .onTapGesture { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { controls.toggle() }; scheduleHide() }
                    .gesture(DragGesture(minimumDistance: 45).onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        session.seek(by: value.translation.width > 0 ? 10 : -10); controls = true; scheduleHide()
                    })
                    .simultaneousGesture(MagnificationGesture().onEnded { value in if value > 1.1 { session.zoom = true } else if value < 0.9 { session.zoom = false } })
                    .accessibilityLabel("Video").accessibilityHint("Usa i controlli per riprodurre o avanzare di dieci secondi.")
                if !session.subtitleText.isEmpty {
                    VStack { Spacer(); Text(session.subtitleText).font(.title3).dynamicTypeSize(...DynamicTypeSize.accessibility2)
                        .multilineTextAlignment(.center).foregroundStyle(.white).padding(8).background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                        .scaleEffect(store.preferences.subtitleScale)
                        .padding(.horizontal, 24).padding(.bottom, controls ? 140 : 28) }
                    .allowsHitTesting(false)
                }
                if controls || voiceOver { chrome(width: geometry.size.width) }
                if session.loading { ProgressView("Caricamento video…").tint(.white).foregroundStyle(.white).padding(20).background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12)) }
                if let error = session.error {
                    VStack(spacing: 16) {
                        Label("Riproduzione non disponibile", systemImage: "exclamationmark.triangle").font(.headline)
                        Text(error).multilineTextAlignment(.center)
                        Button("Riprova") { session.open(anime: route.anime, episode: route.episode) }.buttonStyle(.borderedProminent)
                        Button("Chiudi") { dismiss() }
                    }.padding(24).frame(maxWidth: 480).background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 16)).padding()
                }
            }
        }
        .preferredColorScheme(.dark)
        .task(id: route.id) { session.open(anime: route.anime, episode: route.episode); controls = true; scheduleHide() }
        .onDisappear { hideTask?.cancel(); session.stop() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "srt") ?? .plainText, UTType(filenameExtension: "ass") ?? .plainText, .plainText]) { result in
            switch result { case .success(let url): Task { await session.loadExternalSubtitles(url) }; case .failure(let error): session.subtitleError = error.localizedDescription }
        }
        .alert("Sottotitoli", isPresented: Binding(get: { session.subtitleError != nil }, set: { if !$0 { session.subtitleError = nil } })) { Button("OK") { session.subtitleError = nil } } message: { Text(session.subtitleError ?? "") }
    }
    private func chrome(width: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                IconButton(title: "Chiudi player", symbol: "xmark") { dismiss() }
                VStack(alignment: .leading) { Text(route.anime.title).font(.headline).lineLimit(2); Text(route.episode.title).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if store.preferences.incognito { Image(systemName: "eye.slash.fill").accessibilityLabel("Incognito: progresso non salvato") }
                AirPlayButton().frame(width: 44, height: 44).accessibilityLabel("AirPlay")
                Menu {
                    Button("Importa SRT / ASS") { importing = true }
                    Toggle("Sottotitoli", isOn: $session.captionsEnabled)
                    Toggle("Riempi schermo", isOn: $session.zoom)
                    Menu("Velocità") { ForEach([Float(0.5), 0.75, 1, 1.25, 1.5, 2], id: \.self) { rate in Button("\(rate.formatted())×") { session.setRate(rate) } } }
                    Button(store.preferences.incognito ? "Disattiva incognito" : "Attiva incognito") { store.preferences.incognito.toggle() }
                } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Opzioni lettore")
            }
            Spacer()
            HStack(spacing: width < 400 ? 20 : 40) {
                IconButton(title: "Indietro di dieci secondi", symbol: "gobackward.10") { session.seek(by: -10); scheduleHide() }.font(.title2)
                IconButton(title: session.isPlaying ? "Pausa" : "Riproduci", symbol: session.isPlaying ? "pause.fill" : "play.fill") { session.toggle(); scheduleHide() }.font(.largeTitle)
                    .keyboardShortcut(.space, modifiers: [])
                IconButton(title: "Avanti di dieci secondi", symbol: "goforward.10") { session.seek(by: 10); scheduleHide() }.font(.title2)
            }.disabled(session.loading || session.error != nil)
            Spacer()
            HStack {
                Text(clock(session.seconds)).monospacedDigit().font(.caption)
                Slider(value: Binding(get: { min(max(session.seconds, 0), max(session.duration, 1)) }, set: { session.seek(to: $0); scheduleHide() }), in: 0...max(session.duration, 1)) { Text("Posizione video") }
                    .disabled(session.duration <= 0).accessibilityValue("\(clock(session.seconds)) di \(clock(session.duration))")
                Text(clock(session.duration)).monospacedDigit().font(.caption)
                if let nextEpisode { IconButton(title: "Prossimo episodio", symbol: "forward.end.fill") { app.play(route.anime, episode: nextEpisode) } }
            }
        }.padding(16).foregroundStyle(.white)
            .background { LinearGradient(stops: [.init(color: .black.opacity(0.8), location: 0), .init(color: .clear, location: 0.35), .init(color: .clear, location: 0.65), .init(color: .black.opacity(0.9), location: 1)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false) }
    }
    private func scheduleHide() {
        hideTask?.cancel()
        guard !voiceOver else { return }
        hideTask = Task { do { try await Task.sleep(for: .seconds(4)) } catch { return }; if session.isPlaying { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { controls = false } } }
    }
    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let value = Int(seconds); return value >= 3600 ? String(format: "%d:%02d:%02d", value/3600, value/60%60, value%60) : String(format: "%02d:%02d", value/60, value%60)
    }
}
