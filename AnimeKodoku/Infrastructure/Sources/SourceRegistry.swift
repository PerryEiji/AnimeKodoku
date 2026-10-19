import Foundation
import Combine

@MainActor final class SourceRegistry: ObservableObject {
    @Published private(set) var adapters: [any SourceProtocol] = [MockSource()]
    private let store: LocalStore
    private var manifests: [SourceManifest]
    init(store: LocalStore) throws {
        self.store = store
        manifests = try store.read("sourceManifests") ?? []
        adapters += manifests.map { RESTSource(manifest: $0) }
    }
    func enabled() -> [any SourceProtocol] { adapters.filter { !store.preferences.disabledSourceIds.contains($0.source.id) } }
    func adapter(id: String) throws -> any SourceProtocol {
        guard let adapter = enabled().first(where: { $0.source.id == id }) else { throw AppError.message("Fonte non disponibile o disabilitata. I download locali restano accessibili.") }
        return adapter
    }
    func install(from url: URL) async throws {
        let data = try await NetworkClient.shared.data(from: url)
        try install(data: data)
    }
    func install(data: Data) throws {
        guard data.count <= 1024 * 1024 else { throw AppError.message("Manifest troppo grande.") }
        let manifest = try JSONDecoder().decode(SourceManifest.self, from: data)
        guard manifest.version == 1, manifest.kind == "rest", !manifest.source.id.isEmpty,
              manifest.source.id != "demo", manifest.source.baseUrl.scheme == "https",
              manifest.source.baseUrl.host != nil,
              !manifest.source.id.contains(":"), !manifest.source.id.contains("/") else {
            throw AppError.message("Manifest non valido. Versione 1 e tipo REST HTTPS richiesti; JavaScript e WASM non sono ancora eseguiti.")
        }
        var next = manifests.filter { $0.id != manifest.id }; next.append(manifest)
        try store.write(next, key: "sourceManifests")
        if !manifest.source.isEnabled { store.preferences.disabledSourceIds.insert(manifest.id) }
        manifests = next; adapters = [MockSource()] + manifests.map { RESTSource(manifest: $0) }
    }
}
