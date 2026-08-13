import XCTest
@testable import Feedy

private struct UppercasingTranslator: TextBatchTranslating {
    func translate(_ texts: [String]) async throws -> [String] {
        texts.map { $0.uppercased() }
    }
}

private struct FailingTranslator: TextBatchTranslating {
    struct Failure: Error {}
    func translate(_ texts: [String]) async throws -> [String] { throw Failure() }
}

final class ArticleTranslatorTests: XCTestCase {
    func test_translatesTextNodesPreservingTags() async throws {
        let html = "<p>Hello <a href=\"https://example.com\">world</a></p>"
        let result = try await ArticleTranslator.translatedHTML(from: html, using: UppercasingTranslator())
        XCTAssertTrue(result.contains("HELLO"))
        XCTAssertTrue(result.contains("WORLD"))
        XCTAssertTrue(result.contains("href=\"https://example.com\""))
    }

    func test_returnsOriginalWhenNoTranslatableText() async throws {
        let html = "<img src=\"https://example.com/a.png\">"
        let result = try await ArticleTranslator.translatedHTML(from: html, using: UppercasingTranslator())
        XCTAssertTrue(result.contains("img"))
    }

    func test_propagatesTranslatorErrors() async {
        do {
            _ = try await ArticleTranslator.translatedHTML(from: "<p>Hi</p>", using: FailingTranslator())
            XCTFail("expected error to propagate")
        } catch is FailingTranslator.Failure {
            // expected
        } catch {
            XCTFail("unexpected error type: \(error)")
        }
    }
}
