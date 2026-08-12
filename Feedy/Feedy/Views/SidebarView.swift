import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Binding var selection: SidebarSelection
    @Query(sort: \Feed.title) private var feeds: [Feed]
    @Query private var allArticles: [Article]
    @State private var showingAddSheet = false

    var body: some View {
        List(selection: $selection) {
            Label("All Articles", systemImage: "tray.full")
                .badge(allArticles.filter { !$0.isRead }.count)
                .tag(SidebarSelection.all)

            Section("Feeds") {
                ForEach(feeds) { feed in
                    HStack {
                        Label(feed.title, systemImage: "dot.radiowaves.left.and.right")
                        if !feed.isHealthy {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help(feed.lastErrorMessage ?? "")
                        }
                    }
                    .badge(feed.articles.filter { !$0.isRead }.count)
                    .tag(SidebarSelection.feed(feed.persistentModelID))
                    .contextMenu {
                        Button("Delete Feed", role: .destructive) { delete(feed) }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem { Button { showingAddSheet = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $showingAddSheet) { AddFeedSheet() }
    }

    private func delete(_ feed: Feed) {
        if case .feed(let id) = selection, id == feed.persistentModelID { selection = .all }
        context.delete(feed)
        try? context.save()
    }
}
