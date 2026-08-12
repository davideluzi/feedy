import XCTest
@testable import Feedy

final class HTMLSanitizerTests: XCTestCase {
    private func fixture(_ name: String, _ ext: String) throws -> String {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: ext))
        return try String(contentsOf: url, encoding: .utf8)
    }

    func test_removesScriptsIframesAndInlineHandlers() throws {
        let html = try fixture("dirty-article", "html")
        let out = try HTMLSanitizer().sanitize(html: html, baseURL: "https://blog.example.com/post")
        XCTAssertFalse(out.html.contains("<script"))
        XCTAssertFalse(out.html.contains("<iframe"))
        XCTAssertFalse(out.html.contains("onclick"))
    }

    func test_resolvesRelativeURLsToAbsolute() throws {
        let html = try fixture("dirty-article", "html")
        let out = try HTMLSanitizer().sanitize(html: html, baseURL: "https://blog.example.com/post")
        XCTAssertTrue(out.html.contains("https://blog.example.com/next"))
        XCTAssertTrue(out.html.contains("https://blog.example.com/img/pic.jpg"))
    }

    func test_extractsPlainText() throws {
        let html = try fixture("dirty-article", "html")
        let out = try HTMLSanitizer().sanitize(html: html, baseURL: "https://blog.example.com/post")
        XCTAssertTrue(out.plainText.contains("Read more"))
        XCTAssertFalse(out.plainText.contains("alert"))
    }
}
