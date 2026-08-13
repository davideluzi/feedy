import SwiftUI

struct ArticleDetailView: View {
    let article: Article?

    var body: some View {
        if let article {
            VStack(spacing: 0) {
                if article.bodyHTML.isEmpty {
                    ContentUnavailableView {
                        Label("No Content", systemImage: "doc.plaintext")
                    } description: {
                        Text("This feed did not include the article body.")
                    } actions: {
                        if let link = article.link, let url = URL(string: link) {
                            Link("Open in Browser", destination: url)
                        }
                    }
                } else {
                    WebView(html: ArticleRenderer.document(title: article.title,
                                                           feedName: article.feed?.title,
                                                           bodyHTML: article.bodyHTML),
                            baseURL: article.link.flatMap(URL.init(string:)))
                }
            }
            .toolbar {
                if let link = article.link, let url = URL(string: link) {
                    ToolbarItem {
                        Link(destination: url) { Image(systemName: "safari") }
                            .help("Open in Browser")
                    }
                }
            }
        } else {
            ContentUnavailableView("No Article Selected", systemImage: "doc.text")
        }
    }
}
