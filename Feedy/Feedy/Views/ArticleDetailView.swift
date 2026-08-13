import SwiftUI
import SwiftData
import AppKit

struct ArticleDetailView: View {
    @Environment(\.modelContext) private var context
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
                            baseURL: article.link.flatMap(URL.init(string:)),
                            isRead: article.isRead,
                            link: article.link,
                            onToggleRead: {
                                article.isRead.toggle()
                                try? context.save()
                            })
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
            .contextMenu {
                Button(article.isRead ? "Mark as Unread" : "Mark as Read") {
                    article.isRead.toggle()
                    try? context.save()
                }
                if let link = article.link {
                    Button("Copy Link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(link, forType: .string)
                    }
                }
            }
        } else {
            ContentUnavailableView("No Article Selected", systemImage: "doc.text")
        }
    }
}
