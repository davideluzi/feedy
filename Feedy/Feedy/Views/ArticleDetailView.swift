import SwiftUI
import SwiftData
import AppKit
import Translation

/// Adapts a live TranslationSession (only obtainable via SwiftUI's .translationTask, tied to
/// view lifecycle) to the plain, testable TextBatchTranslating protocol ArticleTranslator uses.
private struct SessionTextTranslator: TextBatchTranslating {
    let session: TranslationSession

    func translate(_ texts: [String]) async throws -> [String] {
        let requests = texts.enumerated().map {
            TranslationSession.Request(sourceText: $1, clientIdentifier: String($0))
        }
        let responses = try await session.translations(from: requests)
        let byIdentifier = Dictionary(uniqueKeysWithValues: responses.compactMap { response in
            response.clientIdentifier.flatMap(Int.init).map { ($0, response.targetText) }
        })
        return texts.indices.map { byIdentifier[$0] ?? texts[$0] }
    }
}

struct ArticleDetailView: View {
    static let defaultFontSize: Double = 16

    @Environment(\.modelContext) private var context
    @AppStorage("articleFontSize") private var fontSize: Double = defaultFontSize
    let article: Article?

    private let fontSizeRange: ClosedRange<Double> = 12...28

    @State private var isTranslated = false
    @State private var isTranslating = false
    @State private var translatedHTML: String?
    @State private var translationConfiguration: TranslationSession.Configuration?
    @State private var translationError: String?

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
                                                           publishedDate: article.publishedDate,
                                                           bodyHTML: (isTranslated ? translatedHTML : nil) ?? article.bodyHTML,
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
                ToolbarItem {
                    Toggle(isOn: Binding(
                        get: { isTranslated },
                        set: { wantsTranslated in
                            if !wantsTranslated {
                                isTranslated = false
                            } else if translatedHTML != nil {
                                isTranslated = true
                            } else {
                                isTranslating = true
                                translationConfiguration = TranslationSession.Configuration(
                                    source: Locale.Language(identifier: "en"),
                                    target: Locale.Language(identifier: "it"))
                            }
                        }
                    )) {
                        if isTranslating {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "translate")
                        }
                    }
                    .help(isTranslated ? "Show Original" : "Translate to Italian")
                    .disabled(isTranslating)
                }
                if let link = article.link, let url = URL(string: link) {
                    ToolbarItem {
                        Button { NSWorkspace.shared.open(url) } label: {
                            Image(systemName: "safari").imageScale(.large)
                        }
                        .help("Open in Browser")
                    }
                }
            }
            .translationTask(translationConfiguration) { session in
                do {
                    let translated = try await ArticleTranslator.translatedHTML(
                        from: article.bodyHTML, using: SessionTextTranslator(session: session))
                    translatedHTML = translated
                    isTranslated = true
                } catch {
                    translationError = error.localizedDescription
                }
                isTranslating = false
            }
            .onChange(of: article.persistentModelID) {
                isTranslated = false
                isTranslating = false
                translatedHTML = nil
                translationConfiguration = nil
                translationError = nil
            }
            .alert("Translation Failed",
                   isPresented: Binding(get: { translationError != nil }, set: { if !$0 { translationError = nil } }),
                   presenting: translationError) { _ in
                Button("OK", role: .cancel) {}
            } message: { message in
                Text(message)
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
