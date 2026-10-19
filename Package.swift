// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "AnimeKodokuCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "AnimeKodokuCore", targets: ["AnimeKodokuCore"])],
    targets: [
        .target(name: "AnimeKodokuCore", path: "AnimeKodoku", exclude: ["App", "Features", "Resources", "Infrastructure/Network", "Infrastructure/Persistence", "Infrastructure/Sources", "Infrastructure/Downloads", "Infrastructure/Tracking", "Infrastructure/Player/PlayerSession.swift"], sources: ["Domain", "Infrastructure/Player/SubtitleParser.swift"]),
        .testTarget(name: "AnimeKodokuCoreTests", dependencies: ["AnimeKodokuCore"], path: "Tests/AnimeKodokuCoreTests")
    ]
)
