//
//  ContentView.swift
//  Feedy
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var feeds: [Feed]
    @State private var selection: SidebarSelection = .all
    @State private var selectedArticle: Article?
    @State private var showOnlyUnread = false
    @State private var searchText = ""
    @State private var didRefreshOnLaunch = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .frame(minWidth: 200)
        } content: {
            ArticleListView(selection: selection,
                            selectedArticle: $selectedArticle,
                            showOnlyUnread: $showOnlyUnread,
                            searchText: $searchText)
                .frame(minWidth: 280)
        } detail: {
            ArticleDetailView(article: selectedArticle)
                .frame(minWidth: 400)
        }
        // Refresh all feeds once on launch.
        .task {
            guard !didRefreshOnLaunch else { return }
            didRefreshOnLaunch = true
            let service = FeedRefreshService(fetcher: URLSessionFetcher(),
                                             parser: FeedKitParser(),
                                             importer: ArticleImporter(sanitizer: HTMLSanitizer()))
            await service.refreshAll(feeds, context: context)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Feed.self, Article.self], inMemory: true)
}
