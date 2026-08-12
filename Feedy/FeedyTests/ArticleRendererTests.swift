import XCTest
@testable import Feedy

final class ArticleRendererTests: XCTestCase {
    func test_wrapsBodyInDocumentWithTitleAndCSS() {
        let html = ArticleRenderer.document(title: "My Post", bodyHTML: "<p>Hi</p>", css: "body{}")
        XCTAssertTrue(html.contains("<style>body{}</style>"))
        XCTAssertTrue(html.contains("<h1>My Post</h1>"))
        XCTAssertTrue(html.contains("<p>Hi</p>"))
        XCTAssertTrue(html.lowercased().contains("<!doctype html>"))
    }

    func test_escapesTitle() {
        let html = ArticleRenderer.document(title: "A & B <x>", bodyHTML: "", css: "")
        XCTAssertTrue(html.contains("A &amp; B &lt;x&gt;"))
    }
}
