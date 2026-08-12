import XCTest
import SwiftData
@testable import Feedy

final class FeedRefreshServiceTests: XCTestCase {
    var container: ModelContainer!

    @MainActor
    func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Feed.self, Article.self, configurations: config)
        return container.mainContext
    }

    @MainActor
    func test_successfulRefreshImportsArticlesAndClearsError() async throws {
        let ctx = try makeContext()
        let feed = Feed(url: "https://x.com/feed", title: "X")
        feed.lastErrorMessage = "old failure"
        ctx.insert(feed)

        let parsed = ParsedFeed(title: "X", siteURL: "https://x.com", articles: [
            ParsedArticle(guid: "g1", link: "https://x.com/1", title: "One",
                          author: nil, publishedDate: nil, contentHTML: "<p>a</p>")
        ])
        let service = FeedRefreshService(
            fetcher: StubFetcher(result: .success(Data("ok".utf8))),
            parser: StubParser(result: .success(parsed)),
            importer: ArticleImporter(sanitizer: PassthroughSanitizer())
        )

        try await service.refresh(feed, context: ctx)
        XCTAssertEqual(feed.articles.count, 1)
        XCTAssertNil(feed.lastErrorMessage)
        XCTAssertNotNil(feed.lastFetchDate)
    }

    @MainActor
    func test_networkFailureRecordsErrorAndKeepsOldArticles() async throws {
        let ctx = try makeContext()
        let feed = Feed(url: "https://x.com/feed", title: "X"); ctx.insert(feed)
        // Seed one existing article.
        let old = Article(identityKey: "old", title: "Old", author: nil, link: nil,
                          publishedDate: nil, bodyHTML: "", bodyPlainText: "")
        old.feed = feed; ctx.insert(old)

        let service = FeedRefreshService(
            fetcher: StubFetcher(result: .failure(URLError(.timedOut))),
            parser: StubParser(result: .success(ParsedFeed(title: nil, siteURL: nil, articles: []))),
            importer: ArticleImporter(sanitizer: PassthroughSanitizer())
        )

        try await service.refresh(feed, context: ctx)
        XCTAssertNotNil(feed.lastErrorMessage)
        XCTAssertEqual(feed.articles.count, 1, "old articles survive a failed refresh")
    }
}

struct StubFetcher: FeedFetching {
    let result: Result<Data, Error>
    func fetch(url: URL) async throws -> Data { try result.get() }
}

struct StubParser: FeedParsing {
    let result: Result<ParsedFeed, Error>
    func parse(data: Data, sourceURL: URL) throws -> ParsedFeed { try result.get() }
}
