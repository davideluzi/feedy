import Foundation

enum ArticleRenderer {
    /// Pure document builder (testable). `fontSize` is layered in as its own <style> tag,
    /// after the base stylesheet, so it overrides the base body font-size on the cascade.
    static func document(title: String, feedName: String?, publishedDate: Date?, bodyHTML: String, css: String, fontSize: Double = 17) -> String {
        let feedNameHTML = feedName.map { "<p class=\"feed-name\">\(escape($0))</p>" } ?? ""
        let dateHTML = publishedDate.map { "<p class=\"published-date\">\(escape($0.formatted(.dateTime.year().month().day())))</p>" } ?? ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        <style>body { font-size: \(fontSize)px; }</style>
        </head>
        <body>
        \(feedNameHTML)
        <h1>\(escape(title))</h1>
        \(dateHTML)
        \(bodyHTML)
        </body>
        </html>
        """
    }

    /// Convenience that loads the bundled stylesheet.
    static func document(title: String, feedName: String?, publishedDate: Date?, bodyHTML: String, fontSize: Double = 17) -> String {
        let css = loadCSS()
        return document(title: title, feedName: feedName, publishedDate: publishedDate, bodyHTML: bodyHTML, css: css, fontSize: fontSize)
    }

    static func loadCSS() -> String {
        guard let url = Bundle.main.url(forResource: "article", withExtension: "css"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
