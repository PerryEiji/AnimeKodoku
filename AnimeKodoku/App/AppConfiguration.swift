import Foundation

enum AppConfiguration {
    // Override via Xcode Scheme environment (debug only) or Info.plist build settings.
    static var demoVideoURL: URL? { configuredURL("DEMO_VIDEO_URL") }
    static var demoSubtitleURL: URL? { configuredURL("DEMO_SUBTITLE_URL") }
    private static func configuredURL(_ key: String) -> URL? {
        let value = ProcessInfo.processInfo.environment[key] ?? (Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "")
        guard !value.isEmpty, !value.hasPrefix("$("), let url = URL(string: value), url.scheme == "https" else { return nil }
        return url
    }
}
