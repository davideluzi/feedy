import XCTest
@testable import Feedy

final class FeedKitParserTests: XCTestCase {
    private func fixtureData(_ name: String, _ ext: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: ext))
        return try Data(contentsOf: url)
    }

    func test_parsesRSSIntoNormalizedModel() throws {
        let data = try fixtureData("sample-rss", "xml")
        let parser = FeedKitParser()
        let feed = try parser.parse(data: data,
                                    sourceURL: URL(string: "https://blog.example.com/feed.xml")!)

        XCTAssertEqual(feed.title, "Example Blog")
        XCTAssertEqual(feed.articles.count, 2)

        let first = feed.articles[0]
        XCTAssertEqual(first.title, "First Post")
        XCTAssertEqual(first.link, "https://blog.example.com/first")
        XCTAssertEqual(first.guid, "https://blog.example.com/first")
        XCTAssertNotNil(first.publishedDate)
        XCTAssertTrue(first.contentHTML.contains("Hello"))
    }

    func test_throwsOnGarbage() {
        let parser = FeedKitParser()
        let data = Data("not a feed".utf8)
        XCTAssertThrowsError(
            try parser.parse(data: data, sourceURL: URL(string: "https://x.com")!)
        )
    }
}
