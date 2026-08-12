import Foundation
import SwiftData

struct ArticleImporter {
    let sanitizer: HTMLSanitizing

    @MainActor
    func importArticles(_ parsed: [ParsedArticle], into feed: Feed,
                        context: ModelContext) throws {
        // Index existing articles of this feed by identity key.
        var existing: [String: Article] = [:]
        for article in feed.articles { existing[article.identityKey] = article }

        for p in parsed {
            let key = ArticleIdentity.key(for: p)
            let base = p.link ?? feed.siteURL ?? feed.url
            let clean = try sanitizer.sanitize(html: p.contentHTML, baseURL: base)

            if let current = existing[key] {
                // Update mutable fields; NEVER touch isRead.
                current.title = p.title ?? current.title
                current.author = p.author
                current.link = p.link
                current.publishedDate = p.publishedDate
                current.bodyHTML = clean.html
                current.bodyPlainText = clean.plainText
            } else {
                let article = Article(
                    identityKey: key,
                    title: p.title ?? "(untitled)",
                    author: p.author,
                    link: p.link,
                    publishedDate: p.publishedDate,
                    bodyHTML: clean.html,
                    bodyPlainText: clean.plainText
                )
                article.feed = feed
                context.insert(article)
                existing[key] = article
            }
        }
        try context.save()
    }
}
