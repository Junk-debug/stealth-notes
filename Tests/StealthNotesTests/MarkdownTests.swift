import XCTest
@testable import StealthNotes

final class MarkdownSectionsTests: XCTestCase {
    func testSplitsOnSeparatorLines() {
        let text = "Intro\n---\nMiddle\n  ---  \nEnd"
        XCTAssertEqual(Markdown.sections(of: text), ["Intro", "Middle", "End"])
    }

    func testDropsEmptySections() {
        XCTAssertEqual(Markdown.sections(of: "---\nOnly\n---\n\n---"), ["Only"])
    }

    func testTextWithoutSeparatorIsOneSection() {
        XCTAssertEqual(Markdown.sections(of: "Just one"), ["Just one"])
    }

    func testEmptyTextStaysOneSection() {
        XCTAssertEqual(Markdown.sections(of: "").count, 1)
    }
}

final class MarkdownBlocksTests: XCTestCase {
    private func describe(_ text: String) -> [String] {
        Markdown.blocks(of: text).map { block in
            switch block {
            case .heading(let s, let level): return "h\(level):\(s)"
            case .bullet(let s): return "bullet:\(s)"
            case .numbered(let s, let n): return "\(n).:\(s)"
            case .quote(let s): return "quote:\(s)"
            case .code(let s): return "code:\(s)"
            case .paragraph(let s): return "p:\(s)"
            case .blank: return "blank"
            }
        }
    }

    func testHeadings() {
        XCTAssertEqual(describe("# One\n## Two\n### Three\n#### Four"),
                       ["h1:One", "h2:Two", "h3:Three", "p:#### Four"])
    }

    func testLists() {
        XCTAssertEqual(describe("- dash\n* star\n12. twelfth"),
                       ["bullet:dash", "bullet:star", "12.:twelfth"])
    }

    func testNumberWithoutSpaceIsParagraph() {
        XCTAssertEqual(describe("3.14 is pi"), ["p:3.14 is pi"])
    }

    func testQuoteAndBlank() {
        XCTAssertEqual(describe("> said\n\nafter"), ["quote:said", "blank", "p:after"])
    }

    func testFencedCodeKeepsRawLines() {
        XCTAssertEqual(describe("```swift\n# not a heading\n  - not a bullet\n```"),
                       ["code:# not a heading\n  - not a bullet"])
    }

    func testUnclosedFenceStillEmitsCode() {
        XCTAssertEqual(describe("```\nlet x = 1"), ["code:let x = 1"])
    }
}
