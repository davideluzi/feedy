import XCTest
@testable import Feedy

final class ArticleIdentityTests: XCTestCase {
    func test_prefersGuidWhenPresent() {
        let a = ParsedArticle(guid: "GUID-1", link: "https://x.com/a",
                              title: "T", author: nil, publishedDate: nil,
                              contentHTML: "")
        XCTAssertEqual(ArticleIdentity.key(for: a), "GUID-1")
    }

    func test_fallsBackToLinkWhenNoGuid() {
        let a = ParsedArticle(guid: nil, link: "https://x.com/a",
                              title: "T", author: nil, publishedDate: nil,
                              contentHTML: "")
        XCTAssertEqual(ArticleIdentity.key(for: a), "https://x.com/a")
    }

    func test_fallsBackToTitleDateHashWhenNoGuidOrLink() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let a = ParsedArticle(guid: nil, link: nil, title: "Hello",
                              author: nil, publishedDate: date, contentHTML: "")
        let b = ParsedArticle(guid: nil, link: nil, title: "Hello",
                              author: nil, publishedDate: date, contentHTML: "")
        XCTAssertEqual(ArticleIdentity.key(for: a), ArticleIdentity.key(for: b))
        XCTAssertFalse(ArticleIdentity.key(for: a).isEmpty)
    }
}
