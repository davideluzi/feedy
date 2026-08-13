import Foundation
import SwiftSoup

protocol TextBatchTranslating {
    func translate(_ texts: [String]) async throws -> [String]
}

/// Translates already-sanitized article HTML by walking its DOM and translating only
/// text-node content, leaving tags/attributes (links, images, structure) untouched —
/// handing raw HTML straight to a translation engine would mangle the markup instead.
/// Along with HTMLSanitizer.swift, this is one of the two files in Feedy allowed to
/// `import SwiftSoup`.
enum ArticleTranslator {
    static func translatedHTML(from html: String, using translator: TextBatchTranslating) async throws -> String {
        let doc = try SwiftSoup.parse(html)
        guard let body = doc.body() else { return html }

        var textNodes: [TextNode] = []
        collectTextNodes(in: body, into: &textNodes)
        guard !textNodes.isEmpty else { return html }

        let originalTexts = textNodes.map { $0.text() }
        let translatedTexts = try await translator.translate(originalTexts)
        guard translatedTexts.count == originalTexts.count else { return html }

        for (node, translated) in zip(textNodes, translatedTexts) {
            _ = node.text(translated)
        }

        return try body.html()
    }

    private static func collectTextNodes(in node: Node, into results: inout [TextNode]) {
        if let textNode = node as? TextNode,
           !textNode.text().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(textNode)
        }
        for child in node.getChildNodes() {
            collectTextNodes(in: child, into: &results)
        }
    }
}
