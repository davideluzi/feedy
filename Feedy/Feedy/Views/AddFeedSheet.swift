import SwiftUI
import SwiftData

struct AddFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var urlString = ""
    @State private var errorMessage: String?
    @State private var isValidating = false

    let parser: FeedParsing = FeedKitParser()
    let fetcher: FeedFetching = URLSessionFetcher()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Feed").font(.headline)
            TextField("https://example.com/feed.xml", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .frame(width: 360)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.caption) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add") { Task { await validateAndAdd() } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isValidating || urlString.isEmpty)
            }
        }
        .padding()
    }

    @MainActor
    private func validateAndAdd() async {
        errorMessage = nil
        isValidating = true
        defer { isValidating = false }
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              url.scheme?.hasPrefix("http") == true else {
            errorMessage = "Enter a valid http(s) URL."; return
        }

        // Pre-check for an existing subscription before hitting the network.
        let target = url.absoluteString
        var descriptor = FetchDescriptor<Feed>(predicate: #Predicate { $0.url == target })
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            errorMessage = "You're already subscribed to this feed."
            return
        }

        let parsed: ParsedFeed
        do {
            let data = try await fetcher.fetch(url: url)
            parsed = try parser.parse(data: data, sourceURL: url)   // validation
        } catch {
            errorMessage = "This does not look like a valid RSS feed."
            return
        }

        let feed = Feed(url: url.absoluteString,
                        title: parsed.title ?? url.host ?? url.absoluteString,
                        siteURL: parsed.siteURL)
        context.insert(feed)
        do {
            try context.save()
        } catch {
            context.delete(feed)
            errorMessage = "Couldn't save the new feed. Please try again."
            return
        }

        do {
            let importer = ArticleImporter(sanitizer: HTMLSanitizer())
            try importer.importArticles(parsed.articles, into: feed, context: context)
            feed.lastFetchDate = .now
            try context.save()
            dismiss()
        } catch {
            // Roll back the feed we just inserted so it doesn't linger, empty
            // and unrecoverable behind the "already subscribed" check, if
            // importing its articles fails.
            context.delete(feed)
            try? context.save()
            errorMessage = "Added the feed but couldn't import its articles. Please try again."
        }
    }
}
