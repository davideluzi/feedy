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
}
