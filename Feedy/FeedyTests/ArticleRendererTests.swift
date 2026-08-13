import XCTest
@testable import Feedy

final class ArticleRendererTests: XCTestCase {
    func test_wrapsBodyInDocumentWithTitleAndCSS() {
        let html = ArticleRenderer.document(title: "My Post", feedName: nil, bodyHTML: "<p>Hi</p>", css: "body{}")
        XCTAssertTrue(html.contains("<style>body{}</style>"))
        XCTAssertTrue(html.contains("<h1>My Post</h1>"))
        XCTAssertTrue(html.contains("<p>Hi</p>"))
        XCTAssertTrue(html.lowercased().contains("<!doctype html>"))
    }

    func test_escapesTitle() {
        let html = ArticleRenderer.document(title: "A & B <x>", feedName: nil, bodyHTML: "", css: "")
        XCTAssertTrue(html.contains("A &amp; B &lt;x&gt;"))
    }

    func test_rendersFeedNameBeforeTitle() {
        let html = ArticleRenderer.document(title: "My Post", feedName: "Daring Fireball", bodyHTML: "", css: "")
        guard let feedNameRange = html.range(of: "<p class=\"feed-name\">Daring Fireball</p>"),
              let titleRange = html.range(of: "<h1>My Post</h1>") else {
            XCTFail("expected both the feed-name element and the h1 title to be present")
            return
        }
        XCTAssertTrue(feedNameRange.lowerBound < titleRange.lowerBound)
    }

    func test_omitsFeedNameElementWhenNil() {
        let html = ArticleRenderer.document(title: "My Post", feedName: nil, bodyHTML: "", css: "")
        XCTAssertFalse(html.contains("feed-name"))
    }

    func test_escapesFeedName() {
        let html = ArticleRenderer.document(title: "My Post", feedName: "A & B <x>", bodyHTML: "", css: "")
        XCTAssertTrue(html.contains("<p class=\"feed-name\">A &amp; B &lt;x&gt;</p>"))
    }
}
