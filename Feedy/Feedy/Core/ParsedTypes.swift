import Foundation

struct ParsedFeed {
    var title: String?
    var siteURL: String?
    var articles: [ParsedArticle]
}

struct ParsedArticle {
    var guid: String?
    var link: String?
    var title: String?
    var author: String?
    var publishedDate: Date?
    var contentHTML: String   // raw HTML from the feed (sanitized later)
}
