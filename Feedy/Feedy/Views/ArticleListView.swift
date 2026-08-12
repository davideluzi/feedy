import SwiftUI

// Stub for Task 9 (app shell). Replaced by the real implementation in Task 11.
struct ArticleListView: View {
    let selection: SidebarSelection
    @Binding var selectedArticle: Article?
    @Binding var showOnlyUnread: Bool
    @Binding var searchText: String

    var body: some View {
        Text("Article List")
    }
}
