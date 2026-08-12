import Foundation
import SwiftData

@Model
final class Feed {
    @Attribute(.unique) var url: String
    var title: String
    var siteURL: String?
    var faviconURL: String?
    var lastFetchDate: Date?
    var lastErrorMessage: String?   // nil == healthy
    @Relationship(deleteRule: .cascade, inverse: \Article.feed)
    var articles: [Article] = []

    init(url: String, title: String, siteURL: String? = nil) {
        self.url = url
        self.title = title
        self.siteURL = siteURL
    }

    var isHealthy: Bool { lastErrorMessage == nil }
}
