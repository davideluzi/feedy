import SwiftUI
import SwiftData
import AppKit

struct ArticleDetailView: View {
    static let defaultFontSize: Double = 16

    @Environment(\.modelContext) private var context
    @AppStorage("articleFontSize") private var fontSize: Double = defaultFontSize
    let article: Article?

    private let fontSizeRange: ClosedRange<Double> = 12...28

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
                                                           bodyHTML: article.bodyHTML,
                                                           fontSize: fontSize),
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
                ToolbarItem {
                    Button { fontSize = max(fontSizeRange.lowerBound, fontSize - 1) } label: {
                        Image(systemName: "textformat.size.smaller")
                    }
                    .keyboardShortcut("-", modifiers: .command)
                    .help("Decrease Font Size")
                    .disabled(fontSize <= fontSizeRange.lowerBound)
                }
                ToolbarItem {
                    Button { fontSize = min(fontSizeRange.upperBound, fontSize + 1) } label: {
                        Image(systemName: "textformat.size.larger")
                    }
                    .keyboardShortcut("+", modifiers: .command)
                    .help("Increase Font Size")
                    .disabled(fontSize >= fontSizeRange.upperBound)
                }
                if let link = article.link, let url = URL(string: link) {
                    ToolbarItem {
                        Link(destination: url) { Image(systemName: "safari") }
                            .help("Open in Browser")
                    }
                }
            }
            .background {
                // Cmd-0 resets font size, mirroring Safari's zoom-reset shortcut. No visible
                // button for it, same as Safari doesn't put "Actual Size" in its toolbar.
                Button("Reset Font Size") { fontSize = Self.defaultFontSize }
                    .keyboardShortcut("0", modifiers: .command)
                    .hidden()
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
