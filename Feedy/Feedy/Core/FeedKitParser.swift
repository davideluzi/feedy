import Foundation
import FeedKit
import XMLKit

/// Maps FeedKit's parsed output into our normalized `ParsedFeed`/`ParsedArticle` model.
///
/// FeedKit 10.4.0 exposes a synchronous, throwing `Feed(data:)` initializer (via the
/// `FeedInitializable` protocol) rather than the older `FeedParser(data:).parse()` API
/// that returns a `Result<Feed, ParserError>`. `Feed` is an enum with `.rss`, `.atom`,
/// and `.json` cases, each wrapping a strongly-typed model. This is the only file in
/// the app that may import FeedKit.
struct FeedKitParser: FeedParsing {
    func parse(data: Data, sourceURL: URL) throws -> ParsedFeed {
        let feed = try FeedKit.Feed(data: data)
        switch feed {
        case .rss(let rss):
            return mapRSS(rss)
        case .atom(let atom):
            return mapAtom(atom)
        case .json(let json):
            return mapJSON(json)
        }
    }

    private func mapRSS(_ feed: RSSFeed) -> ParsedFeed {
        let channel = feed.channel
        let items = (channel?.items ?? []).map { item in
            ParsedArticle(
                guid: item.guid?.text,
                link: item.link,
                title: item.title,
                author: item.author ?? item.dublinCore?.creator,
                publishedDate: item.pubDate,
                contentHTML: item.content?.encoded ?? item.description ?? ""
            )
        }
        return ParsedFeed(title: channel?.title, siteURL: channel?.link, articles: items)
    }

    private func mapAtom(_ feed: AtomFeed) -> ParsedFeed {
        let items = (feed.entries ?? []).map { entry in
            ParsedArticle(
                guid: entry.id,
                link: alternateLink(entry.links),
                title: entry.title,
                author: entry.authors?.first?.name,
                publishedDate: entry.published ?? entry.updated,
                contentHTML: entry.content?.text ?? entry.summary?.text ?? ""
            )
        }
        return ParsedFeed(title: feed.title?.text, siteURL: alternateLink(feed.links), articles: items)
    }

    private func mapJSON(_ feed: JSONFeed) -> ParsedFeed {
        let items = (feed.items ?? []).map { item in
            ParsedArticle(
                guid: item.id,
                link: item.url,
                title: item.title,
                author: item.author?.name,
                publishedDate: item.datePublished,
                contentHTML: item.contentHtml ?? item.contentText ?? ""
            )
        }
        return ParsedFeed(title: feed.title, siteURL: feed.homePageURL, articles: items)
    }

    /// Picks the best link href from an Atom `<link>` list: prefers `rel="alternate"`,
    /// falls back to the first link with an href.
    private func alternateLink(_ links: [AtomFeedLink]?) -> String? {
        guard let links else { return nil }
        if let alternate = links.first(where: { $0.attributes?.rel == "alternate" })?.attributes?.href {
            return alternate
        }
        return links.first?.attributes?.href
    }
}
