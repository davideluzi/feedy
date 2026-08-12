import Foundation
import CryptoKit

protocol FeedParsing {
    /// Parse raw feed bytes into our normalized model.
    func parse(data: Data, sourceURL: URL) throws -> ParsedFeed
}

enum ArticleIdentity {
    /// Stable per-article key: guid ?? link ?? hash(title + publishedDate).
    static func key(for article: ParsedArticle) -> String {
        if let g = article.guid, !g.isEmpty { return g }
        if let l = article.link, !l.isEmpty { return l }
        let basis = (article.title ?? "") + "|" + (article.publishedDate?.description ?? "")
        let digest = SHA256.hash(data: Data(basis.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
