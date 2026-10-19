import Foundation

struct TrackerPlaceholder: TrackerService {
    let name: String
    func updateProgress(anime: Anime, episode: Episode) async throws {
        throw AppError.message("\(name): integrazione non configurata. Il progresso è stato salvato solo sul dispositivo.")
    }
}
