import XCTest
@testable import AnimeKodokuCore

final class SubtitleParserTests: XCTestCase {
    func testSRTBOMCRLFAndMilliseconds() throws {
        let text = "\u{FEFF}1\r\n00:00:01,250 --> 00:00:03,500\r\nCiao <i>mondo</i>\r\n\r\n"
        let cues = try SubtitleParser.parse(text, extension: "SRT")
        XCTAssertEqual(cues.count, 1); XCTAssertEqual(cues[0].start, 1.25); XCTAssertEqual(cues[0].end, 3.5)
        XCTAssertEqual(cues[0].text, "Ciao mondo")
    }
    func testEndBoundaryDoesNotKeepExpiredCaption() throws {
        let cues = try SubtitleParser.parse("1\n00:00:01,000 --> 00:00:02,000\nCiao\n", extension: "srt")
        XCTAssertEqual(SubtitleParser.activeText(at: 0.99, cues: cues), "")
        XCTAssertEqual(SubtitleParser.activeText(at: 1, cues: cues), "Ciao")
        XCTAssertEqual(SubtitleParser.activeText(at: 2, cues: cues), "")
    }
    func testOverlappingCaptions() throws {
        let text = "1\n00:00:01,000 --> 00:00:03,000\nUno\n\n2\n00:00:02,000 --> 00:00:04,000\nDue\n"
        let cues = try SubtitleParser.parse(text, extension: "srt")
        XCTAssertEqual(SubtitleParser.activeText(at: 2.5, cues: cues), "Uno\nDue")
    }
    func testASSCommasOverrideTagsAndLineBreaks() throws {
        let text = #"""
        [Script Info]
        Title: Test
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.25,0:00:04.50,Default,,0,0,0,,{\i1}Ciao, mondo!\NSeconda riga
        """#
        let cues = try SubtitleParser.parse(text, extension: "ass")
        XCTAssertEqual(cues.count, 1); XCTAssertEqual(cues[0].start, 1.25)
        XCTAssertEqual(cues[0].text, "Ciao, mondo!\nSeconda riga")
    }
    func testASSCustomFieldOrder() throws {
        let text = "[Events]\nFormat: End, Start, Text\nDialogue: 0:00:04.00,0:00:02.00,Test\n"
        let cues = try SubtitleParser.parse(text, extension: "ass")
        XCTAssertEqual(cues[0].start, 2); XCTAssertEqual(cues[0].end, 4)
    }
    func testRejectsMalformedTimeAndNegativeIntervals() {
        for text in ["1\nwrong:00:00:01 --> 00:00:04\nA\n", "1\n00:61:00 --> 00:62:00\nA\n", "1\n00:00:05 --> 00:00:01\nA\n"] {
            XCTAssertThrowsError(try SubtitleParser.parse(text, extension: "srt"))
        }
    }
    func testUnsupportedExtensionFailsExplicitly() { XCTAssertThrowsError(try SubtitleParser.parse("test", extension: "vtt")) }
    func testUnicodeAndSortedCues() throws {
        let text = "2\n00:00:04,000 --> 00:00:05,000\n星空\n\n1\n00:00:01,000 --> 00:00:02,000\nこんにちは\n"
        let cues = try SubtitleParser.parse(text, extension: "srt")
        XCTAssertEqual(cues.map(\.text), ["こんにちは", "星空"])
    }
}
