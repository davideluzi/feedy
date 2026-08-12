import SwiftUI
import SwiftData

struct ArticleListView: View {
    @Environment(\.modelContext) private var context
    let selection: SidebarSelection
    @Binding var selectedArticle: Article?
    @Binding var showOnlyUnread: Bool
    @Binding var searchText: String

    @Query private var feeds: [Feed]
    @State private var isRefreshing = false

    // Resolve the currently selected feed (if any).
    private var selectedFeed: Feed? {
        if case .feed(let id) = selection {
            return feeds.first { $0.persistentModelID == id }
        }
        return nil
    }

    // Combine the three orthogonal filters in memory over the relevant set.
    private var articles: [Article] {
        let base: [Article] = selectedFeed?.articles ?? feeds.flatMap { $0.articles }
        return base
            .filter { showOnlyUnread ? !$0.isRead : true }
            .filter { searchText.isEmpty
                ? true
                : ($0.title.localizedStandardContains(searchText)
                   || ($0.author?.localizedStandardContains(searchText) ?? false)) }
            .sorted { ($0.publishedDate ?? .distantPast) > ($1.publishedDate ?? .distantPast) }
    }

    var body: some View {
        List(selection: $selectedArticle) {
            ForEach(articles) { article in
                ArticleRow(article: article)
                    .tag(article)
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search title or author")
        .onChange(of: selectedArticle) { _, new in new?.isRead = true; try? context.save() }
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showOnlyUnread) { Image(systemName: "circle.fill") }
                    .help("Show only unread")
            }
            ToolbarItem {
                Button { markAllRead() } label: { Image(systemName: "checkmark.circle") }
                    .help("Mark all as read")
            }
            ToolbarItem {
                Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .keyboardShortcut("r")
                    .disabled(isRefreshing)
            }
        }
        .overlay { if articles.isEmpty { ContentUnavailableView("No Articles", systemImage: "tray") } }
    }

    private func markAllRead() {
        for a in articles { a.isRead = true }
        try? context.save()
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true; defer { isRefreshing = false }
        let service = FeedRefreshService(fetcher: URLSessionFetcher(),
                                         parser: FeedKitParser(),
                                         importer: ArticleImporter(sanitizer: HTMLSanitizer()))
        let toRefresh = selectedFeed.map { [$0] } ?? feeds
        await service.refreshAll(toRefresh, context: context)
    }
}

struct ArticleRow: View {
    @Environment(\.modelContext) private var context
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button { article.isRead.toggle(); try? context.save() } label: {
                Image(systemName: article.isRead ? "circle" : "circle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(article.isRead ? .secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(article.isRead ? "Mark as unread" : "Mark as read")

            VStack(alignment: .leading, spacing: 2) {
                Text(article.title).font(.headline).lineLimit(2)
                if let date = article.publishedDate {
                    Text(date, format: .dateTime.year().month().day())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
