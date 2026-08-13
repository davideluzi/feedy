import Foundation

enum ArticleRenderer {
    /// Pure document builder (testable).
    static func document(title: String, feedName: String?, bodyHTML: String, css: String) -> String {
        let feedNameHTML = feedName.map { "<p class=\"feed-name\">\(escape($0))</p>" } ?? ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>
        \(feedNameHTML)
        <h1>\(escape(title))</h1>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    /// Convenience that loads the bundled stylesheet.
    static func document(title: String, feedName: String?, bodyHTML: String) -> String {
        let css = loadCSS()
        return document(title: title, feedName: feedName, bodyHTML: bodyHTML, css: css)
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
