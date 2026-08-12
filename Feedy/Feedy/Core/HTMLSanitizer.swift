import Foundation
import SwiftSoup

/// Cleaned article content: sanitized HTML with absolute URLs, plus a plain-text
/// extraction (persisted now, used for full-text search in a future version).
struct SanitizedContent {
    var html: String
    var plainText: String
}

/// The only file in Feedy allowed to `import SwiftSoup`. Cleans feed HTML once:
/// drops dangerous/inconsistent elements, resolves relative URLs to absolute
/// against the article link, and produces both cleaned HTML and plain text.
struct HTMLSanitizer {
    func sanitize(html: String, baseURL: String) throws -> SanitizedContent {
        // Parse with a base URI so relative URLs can be made absolute.
        let dirty = try SwiftSoup.parse(html, baseURL)

        // Build an allowlist of semantic tags + the attributes we keep.
        let allow = try Whitelist.relaxed()
            .addTags("figure", "figcaption", "h1", "h2", "h3", "pre")
            .preserveRelativeLinks(false)   // emit absolute href/src

        let cleaner = Cleaner(headWhitelist: nil, bodyWhitelist: allow)
        let clean = try cleaner.clean(dirty)
        clean.outputSettings().prettyPrint(pretty: false)

        // Rewrite remaining relative URLs to absolute (belt-and-suspenders).
        for el in try clean.select("[href]") {
            let abs = try el.absUrl("href")
            if !abs.isEmpty { try el.attr("href", abs) }
        }
        for el in try clean.select("[src]") {
            let abs = try el.absUrl("src")
            if !abs.isEmpty { try el.attr("src", abs) }
        }

        let cleanedHTML = try clean.body()?.html() ?? ""
        let plain = try clean.text()
        return SanitizedContent(html: cleanedHTML, plainText: plain)
    }
}
