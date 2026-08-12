import Foundation
import SwiftData

struct FeedRefreshService {
    let fetcher: FeedFetching
    let parser: FeedParsing
    let importer: ArticleImporter

    @MainActor
    func refresh(_ feed: Feed, context: ModelContext) async throws {
        guard let url = URL(string: feed.url) else {
            feed.lastErrorMessage = "Invalid URL"; try context.save(); return
        }
        do {
            let data = try await fetcher.fetch(url: url)
            let parsed = try parser.parse(data: data, sourceURL: url)
            if let t = parsed.title, !t.isEmpty, feed.title.isEmpty { feed.title = t }
            if feed.siteURL == nil { feed.siteURL = parsed.siteURL }
            try importer.importArticles(parsed.articles, into: feed, context: context)
            feed.lastErrorMessage = nil
            feed.lastFetchDate = .now
            try context.save()
        } catch {
            // Non-blocking: record the error, keep existing articles.
            feed.lastErrorMessage = error.localizedDescription
            feed.lastFetchDate = .now
            try context.save()
        }
    }

    /// Refresh many feeds with bounded concurrency (max 5 at a time).
    @MainActor
    func refreshAll(_ feeds: [Feed], context: ModelContext) async {
        let chunks = stride(from: 0, to: feeds.count, by: 5).map {
            Array(feeds[$0..<min($0 + 5, feeds.count)])
        }
        for chunk in chunks {
            await withTaskGroup(of: Void.self) { group in
                for feed in chunk {
                    group.addTask { @MainActor in try? await self.refresh(feed, context: context) }
                }
            }
        }
    }
}
