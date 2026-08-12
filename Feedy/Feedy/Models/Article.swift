import Foundation
import SwiftData

@Model
final class Article {
    var identityKey: String     // guid ?? link ?? hash(title+date); unique per feed
    var title: String
    var author: String?
    var link: String?
    var publishedDate: Date?
    var bodyHTML: String        // sanitized HTML
    var bodyPlainText: String   // for future full-text search
    var isRead: Bool
    var fetchedAt: Date
    var feed: Feed?

    init(identityKey: String, title: String, author: String?, link: String?,
         publishedDate: Date?, bodyHTML: String, bodyPlainText: String,
         isRead: Bool = false, fetchedAt: Date = .now, feed: Feed? = nil) {
        self.identityKey = identityKey
        self.title = title
        self.author = author
        self.link = link
        self.publishedDate = publishedDate
        self.bodyHTML = bodyHTML
        self.bodyPlainText = bodyPlainText
        self.isRead = isRead
        self.fetchedAt = fetchedAt
        self.feed = feed
    }
}
