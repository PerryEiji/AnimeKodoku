import XCTest
@testable import AnimeKodokuCore

final class DomainTests: XCTestCase {
    private let anime = Anime(id: "test:42", sourceId: "test", title: "Stelle", description: "Prova", tags: ["Avventura"])
    func testFiltersIntersectInsteadOfUnion() {
        let entry = LibraryEntry(animeId: anime.id, status: .watching)
        XCTAssertTrue(LibraryFilter(status: .watching, sourceId: "test", tag: "Avventura").matches(anime, entry: entry))
        XCTAssertFalse(LibraryFilter(status: .completed, sourceId: "test", tag: "Avventura").matches(anime, entry: entry))
        XCTAssertFalse(LibraryFilter(sourceId: "other").matches(anime, entry: entry))
        XCTAssertTrue(LibraryFilter().matches(anime, entry: entry))
    }
    func testIdentityDoesNotDependOnTitle() {
        var other = anime; other.id = "another:42"; other.sourceId = "another"
        XCTAssertEqual(Set([anime, other]).count, 2)
    }
    func testPreferencesRoundTripPreservesStableFilterIDs() throws {
        var value = Preferences(); value.libraryFilter = LibraryFilter(status: .watching, sourceId: "test", tag: "Avventura")
        value.sourceFilters["test"] = [Filter(id: "sort", value: "descending")]
        value.groups = [SavedGroup(name: "In corso", filter: value.libraryFilter)]
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(value))
        XCTAssertEqual(decoded, value)
    }
    func testEpisodeProgressCodableRoundTrip() throws {
        let episode = Episode(id: "test:42:1", animeId: anime.id, number: 1, title: "Pilota", duration: 1400, progress: 352)
        XCTAssertEqual(try JSONDecoder().decode(Episode.self, from: JSONEncoder().encode(episode)), episode)
    }
    func testBackupRoundTripRetainsProgressAndHistory() throws {
        var preferences = Preferences(); preferences.searchHistory = ["Stelle"]
        let episode = Episode(id: "test:42:1", animeId: anime.id, number: 1, title: "Pilota", duration: 1200, progress: 1100)
        let entry = LibraryEntry(animeId: anime.id, status: .watching, lastEpisodeId: episode.id, lastProgress: 1100)
        let backup = Backup(version: 1, createdAt: Date(), library: [entry], anime: [anime], episodes: [episode], preferences: preferences)
        let decoded = try JSONDecoder().decode(Backup.self, from: JSONEncoder().encode(backup))
        XCTAssertEqual(decoded.library, [entry]); XCTAssertEqual(decoded.episodes, [episode]); XCTAssertEqual(decoded.preferences, preferences)
    }
}
