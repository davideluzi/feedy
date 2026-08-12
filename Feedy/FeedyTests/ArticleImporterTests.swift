import XCTest
import SwiftData
@testable import Feedy

final class ArticleImporterTests: XCTestCase {
    var container: ModelContainer!

    @MainActor
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Feed.self, Article.self, configurations: config)
        return container.mainContext
    }

    @MainActor
    func test_canPersistAndFetchFeed() throws {
        let ctx = try makeContext()
        let feed = Feed(url: "https://blog.example.com/feed.xml", title: "Example")
        ctx.insert(feed)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Feed>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "Example")
    }

    @MainActor
    func test_insertsNewArticles() throws {
        let ctx = try makeContext()
        let feed = Feed(url: "https://x.com/feed", title: "X"); ctx.insert(feed)
        let parsed = [ParsedArticle(guid: "g1", link: "https://x.com/1", title: "One",
                                    author: nil, publishedDate: nil, contentHTML: "<p>a</p>")]
        let importer = ArticleImporter(sanitizer: PassthroughSanitizer())
        try importer.importArticles(parsed, into: feed, context: ctx)

        XCTAssertEqual(feed.articles.count, 1)
        XCTAssertEqual(feed.articles.first?.identityKey, "g1")
    }

    @MainActor
    func test_doesNotDuplicateOnReimport() throws {
        let ctx = try makeContext()
        let feed = Feed(url: "https://x.com/feed", title: "X"); ctx.insert(feed)
        let parsed = [ParsedArticle(guid: "g1", link: nil, title: "One",
                                    author: nil, publishedDate: nil, contentHTML: "<p>a</p>")]
        let importer = ArticleImporter(sanitizer: PassthroughSanitizer())
        try importer.importArticles(parsed, into: feed, context: ctx)
        try importer.importArticles(parsed, into: feed, context: ctx)
        XCTAssertEqual(feed.articles.count, 1)
    }

    @MainActor
    func test_preservesReadFlagOnReimport() throws {
        let ctx = try makeContext()
        let feed = Feed(url: "https://x.com/feed", title: "X"); ctx.insert(feed)
        let importer = ArticleImporter(sanitizer: PassthroughSanitizer())
        let parsed = [ParsedArticle(guid: "g1", link: nil, title: "One",
                                    author: nil, publishedDate: nil, contentHTML: "<p>a</p>")]
        try importer.importArticles(parsed, into: feed, context: ctx)
        feed.articles.first?.isRead = true
        try ctx.save()

        // Re-import with a changed title.
        let updated = [ParsedArticle(guid: "g1", link: nil, title: "One (edited)",
                                     author: nil, publishedDate: nil, contentHTML: "<p>b</p>")]
        try importer.importArticles(updated, into: feed, context: ctx)

        let article = try XCTUnwrap(feed.articles.first)
        XCTAssertTrue(article.isRead, "read flag must survive re-import")
        XCTAssertEqual(article.title, "One (edited)", "mutable fields update")
    }
}

/// Test sanitizer that returns the input unchanged so importer tests stay pure.
struct PassthroughSanitizer: HTMLSanitizing {
    func sanitize(html: String, baseURL: String) throws -> SanitizedContent {
        SanitizedContent(html: html, plainText: html)
    }
}
