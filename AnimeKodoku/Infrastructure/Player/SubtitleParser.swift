import Foundation

public struct SubtitleCue: Identifiable, Hashable, Sendable {
    public var id: Int
    public var start: Double
    public var end: Double
    public var text: String
}
public enum SubtitleParser {
    public static func parse(_ text: String, extension ext: String) throws -> [SubtitleCue] {
        let cleaned = text.replacingOccurrences(of: "\u{FEFF}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let result: [SubtitleCue]
        switch ext.lowercased() {
        case "srt": result = srt(cleaned)
        case "ass", "ssa": result = ass(cleaned)
        default: throw AppError.message("Formato sottotitoli non supportato. Usa SRT o ASS/SSA.")
        }
        guard !result.isEmpty else { throw AppError.message("Nessuna battuta valida nel file sottotitoli.") }
        return result.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
    public static func activeText(at seconds: Double, cues: [SubtitleCue]) -> String {
        // Stop at future cues; overlaps are kept (e.g. multiple speakers).
        cues.prefix { $0.start <= seconds }.filter { seconds < $0.end }.map(\.text).joined(separator: "\n")
    }
    private static func timestamp(_ raw: String) -> Double? {
        guard raw.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false).count == 3 else { return nil }
        let values = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").split(separator: ":").compactMap { Double($0) }
        guard values.count == 3, values.allSatisfy({ $0.isFinite && $0 >= 0 }), values[1] < 60, values[2] < 60 else { return nil }
        return values[0]*3600 + values[1]*60 + values[2]
    }
    private static func strip(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\N", with: "\n").replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\h", with: " ")
            .replacingOccurrences(of: #"\{[^}]*\}"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private static func srt(_ text: String) -> [SubtitleCue] {
        var result: [SubtitleCue] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        while i < lines.count {
            guard lines[i].contains("-->") else { i += 1; continue }
            let times = lines[i].components(separatedBy: "-->")
            let endRaw = times.count == 2 ? String(times[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first ?? "") : ""
            i += 1
            var body: [String] = []
            while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).isEmpty { body.append(lines[i]); i += 1 }
            guard times.count == 2, let start = timestamp(times[0]), let end = timestamp(endRaw), end > start else { continue }
            let value = strip(body.joined(separator: "\n"))
            if !value.isEmpty { result.append(SubtitleCue(id: result.count, start: start, end: end, text: value)) }
        }
        return result
    }
    private static func ass(_ text: String) -> [SubtitleCue] {
        var fields = ["layer", "start", "end", "style", "name", "marginl", "marginr", "marginv", "effect", "text"]
        var inEvents = false
        var result: [SubtitleCue] = []
        for line in text.components(separatedBy: "\n") {
            let line = line.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("[") { inEvents = line.lowercased() == "[events]"; continue }
            guard inEvents else { continue }
            if line.lowercased().hasPrefix("format:") { fields = line.dropFirst(7).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }; continue }
            guard line.lowercased().hasPrefix("dialogue:"), fields.last == "text", let s = fields.firstIndex(of: "start"), let e = fields.firstIndex(of: "end") else { continue }
            let parts = line.dropFirst(9).split(separator: ",", maxSplits: fields.count-1, omittingEmptySubsequences: false).map(String.init)
            guard parts.count == fields.count, let start = timestamp(parts[s]), let end = timestamp(parts[e]), end > start else { continue }
            let value = strip(parts.last ?? "")
            if !value.isEmpty { result.append(SubtitleCue(id: result.count, start: start, end: end, text: value)) }
        }
        return result
    }
}
