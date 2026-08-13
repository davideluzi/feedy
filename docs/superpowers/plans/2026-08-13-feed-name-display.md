# Feed Name Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show each article's feed name above its title in both the article list row and the rendered article detail view.

**Architecture:** `Feed.title` already exists and is already populated at add time (`AddFeedSheet.swift`) from the parsed feed's own title — no data-layer change. This plan only touches two presentation points: `ArticleRenderer` (which now bakes the feed name into the sanitized HTML document, styled via `article.css`) and `ArticleListView.ArticleRow` (which gets a native SwiftUI caption line). `Article.feed?.title` is the read path for both.

**Tech Stack:** Swift, SwiftUI, XCTest. No new dependencies.

## Global Constraints

- Build from `/Users/davide/GitHub/feedy/Feedy` (directory containing `Feedy.xcodeproj`).
- Build command: `xcodebuild -scheme Feedy -destination 'platform=macOS' build`
- Full test command: `xcodebuild test -scheme Feedy -destination 'platform=macOS'`
- Single-class test command: `xcodebuild test -scheme Feedy -destination 'platform=macOS' -only-testing:FeedyTests/<TestClassName>`
- `ArticleRenderer` is the pure/testable layer per `CLAUDE.md`; keep it free of SwiftUI/SwiftData imports.
- Feed names come from untrusted external feed content — any feed name inserted into rendered HTML must go through the same `escape()` helper already used for the article title.
- No schema changes to `Feed` or `Article`.

---

### Task 1: Feed name in the article detail view (`ArticleRenderer` + `article.css` + `ArticleDetailView`)

**Files:**
- Modify: `Feedy/Feedy/Core/ArticleRenderer.swift`
- Modify: `Feedy/Feedy/Resources/article.css`
- Modify: `Feedy/Feedy/Views/ArticleDetailView.swift:20-22`
- Test: `Feedy/FeedyTests/ArticleRendererTests.swift`

**Interfaces:**
- Consumes: `Article.feed: Feed?` (existing relationship, `Feedy/Feedy/Models/Article.swift:15`), `Feed.title: String` (existing, `Feedy/Feedy/Models/Feed.swift:7`).
- Produces: `ArticleRenderer.document(title: String, feedName: String?, bodyHTML: String, css: String) -> String` and `ArticleRenderer.document(title: String, feedName: String?, bodyHTML: String) -> String` — both replace the current 3-arg/2-arg overloads (no `feedName` parameter today). Task 2 does not depend on this signature.

- [ ] **Step 1: Write the failing/updated tests**

Replace the full contents of `Feedy/FeedyTests/ArticleRendererTests.swift`:

```swift
import XCTest
@testable import Feedy

final class ArticleRendererTests: XCTestCase {
    func test_wrapsBodyInDocumentWithTitleAndCSS() {
        let html = ArticleRenderer.document(title: "My Post", feedName: nil, bodyHTML: "<p>Hi</p>", css: "body{}")
        XCTAssertTrue(html.contains("<style>body{}</style>"))
        XCTAssertTrue(html.contains("<h1>My Post</h1>"))
        XCTAssertTrue(html.contains("<p>Hi</p>"))
        XCTAssertTrue(html.lowercased().contains("<!doctype html>"))
    }

    func test_escapesTitle() {
        let html = ArticleRenderer.document(title: "A & B <x>", feedName: nil, bodyHTML: "", css: "")
        XCTAssertTrue(html.contains("A &amp; B &lt;x&gt;"))
    }

    func test_rendersFeedNameBeforeTitle() {
        let html = ArticleRenderer.document(title: "My Post", feedName: "Daring Fireball", bodyHTML: "", css: "")
        guard let feedNameRange = html.range(of: "<p class=\"feed-name\">Daring Fireball</p>"),
              let titleRange = html.range(of: "<h1>My Post</h1>") else {
            XCTFail("expected both the feed-name element and the h1 title to be present")
            return
        }
        XCTAssertTrue(feedNameRange.lowerBound < titleRange.lowerBound)
    }

    func test_omitsFeedNameElementWhenNil() {
        let html = ArticleRenderer.document(title: "My Post", feedName: nil, bodyHTML: "", css: "")
        XCTAssertFalse(html.contains("feed-name"))
    }

    func test_escapesFeedName() {
        let html = ArticleRenderer.document(title: "My Post", feedName: "A & B <x>", bodyHTML: "", css: "")
        XCTAssertTrue(html.contains("<p class=\"feed-name\">A &amp; B &lt;x&gt;</p>"))
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `xcodebuild test -scheme Feedy -destination 'platform=macOS' -only-testing:FeedyTests/ArticleRendererTests`
Expected: build error — `ArticleRenderer.document` has no `feedName` parameter yet (`extra argument 'feedName' in call`).

- [ ] **Step 3: Implement the `feedName` parameter in `ArticleRenderer`**

Replace the full contents of `Feedy/Feedy/Core/ArticleRenderer.swift`:

```swift
import Foundation

enum ArticleRenderer {
    /// Pure document builder (testable).
    static func document(title: String, feedName: String?, bodyHTML: String, css: String) -> String {
        let feedNameHTML = feedName.map { "<p class=\"feed-name\">\(escape($0))</p>" } ?? ""
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>
        \(feedNameHTML)
        <h1>\(escape(title))</h1>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    /// Convenience that loads the bundled stylesheet.
    static func document(title: String, feedName: String?, bodyHTML: String) -> String {
        let css = loadCSS()
        return document(title: title, feedName: feedName, bodyHTML: bodyHTML, css: css)
    }

    static func loadCSS() -> String {
        guard let url = Bundle.main.url(forResource: "article", withExtension: "css"),
              let s = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return s
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
```

- [ ] **Step 4: Add the `.feed-name` style to `article.css`**

In `Feedy/Feedy/Resources/article.css`, insert this new rule immediately after the closing `}` of the `body { ... }` block (i.e. right before the existing `h1, h2, h3 { line-height: 1.25; }` line):

```css
.feed-name {
  color: var(--muted); font-size: 0.85em; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.02em; margin: 0 0 0.4em;
}
```

- [ ] **Step 5: Update the `ArticleDetailView` call site**

In `Feedy/Feedy/Views/ArticleDetailView.swift`, change:

```swift
                    WebView(html: ArticleRenderer.document(title: article.title,
                                                           bodyHTML: article.bodyHTML),
                            baseURL: article.link.flatMap(URL.init(string:)))
```

to:

```swift
                    WebView(html: ArticleRenderer.document(title: article.title,
                                                           feedName: article.feed?.title,
                                                           bodyHTML: article.bodyHTML),
                            baseURL: article.link.flatMap(URL.init(string:)))
```

- [ ] **Step 6: Run the tests and confirm they pass**

Run: `xcodebuild test -scheme Feedy -destination 'platform=macOS' -only-testing:FeedyTests/ArticleRendererTests`
Expected: PASS, 5 tests, 0 failures.

- [ ] **Step 7: Build the full app target**

Run: `xcodebuild -scheme Feedy -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **` (confirms `ArticleDetailView.swift` compiles against the new signature).

- [ ] **Step 8: Commit**

```bash
cd /Users/davide/GitHub/feedy
git add Feedy/Feedy/Core/ArticleRenderer.swift Feedy/Feedy/Resources/article.css Feedy/Feedy/Views/ArticleDetailView.swift Feedy/FeedyTests/ArticleRendererTests.swift
git commit -m "Show feed name above the article title in the detail view"
```

---

### Task 2: Feed name in the article list row (`ArticleListView.ArticleRow`)

**Files:**
- Modify: `Feedy/Feedy/Views/ArticleListView.swift:77-102` (the `ArticleRow` struct)

**Interfaces:**
- Consumes: `Article.feed: Feed?`, `Feed.title: String` (same as Task 1; independent of Task 1's `ArticleRenderer` change — this task only touches `ArticleListView.swift`).
- Produces: nothing consumed by later tasks (this is the last task in the plan).

No new automated test: `ArticleRow` has no existing test coverage today (view-layer code in this codebase is untested, per `CLAUDE.md`), and this change doesn't introduce a pure/testable function — consistent with existing project conventions. Verification is a full build plus the existing full test suite (to catch any regression elsewhere), plus a manual run.

- [ ] **Step 1: Add the feed name line to `ArticleRow`**

In `Feedy/Feedy/Views/ArticleListView.swift`, change:

```swift
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title).font(.headline).lineLimit(2)
                Text(article.bodyPlainText.prefix(240)).font(.system(size: 11)).lineLimit(3)
                if let date = article.publishedDate {
                    Text(date, format: .dateTime.year().month().day())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
```

to:

```swift
            VStack(alignment: .leading, spacing: 2) {
                if let feedName = article.feed?.title, !feedName.isEmpty {
                    Text(feedName).font(.caption2).foregroundStyle(.secondary)
                }
                Text(article.title).font(.headline).lineLimit(2)
                Text(article.bodyPlainText.prefix(240)).font(.system(size: 11)).lineLimit(3)
                if let date = article.publishedDate {
                    Text(date, format: .dateTime.year().month().day())
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
```

- [ ] **Step 2: Build the full app target**

Run: `xcodebuild -scheme Feedy -destination 'platform=macOS' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Run the full test suite**

Run: `xcodebuild test -scheme Feedy -destination 'platform=macOS'`
Expected: all existing tests still PASS (this step only guards against an unrelated regression; no new tests were added in this task).

- [ ] **Step 4: Manual check**

Launch the app (Xcode run, or `open` the built `.app` from Step 2's `DerivedData` products path), select "All Articles" or any feed, and confirm each row shows the feed's name in a small secondary-colored line directly above the article title. Open an article and confirm the feed name appears above the `<h1>` title in the detail pane, styled as a small uppercase muted label.

- [ ] **Step 5: Commit**

```bash
cd /Users/davide/GitHub/feedy
git add Feedy/Feedy/Views/ArticleListView.swift
git commit -m "Show feed name above the article title in the article list"
```

---

## Self-Review Notes

- **Spec coverage:** Source of the name (existing `Feed.title`, no fetch change) → no task needed, confirmed as a non-goal. List display, always-on → Task 2. Detail view, rendered inside HTML/CSS → Task 1. Testing (escape, ordering, nil case) → Task 1 Step 1. All spec sections covered.
- **Placeholder scan:** none found — every step has literal code.
- **Type consistency:** `ArticleRenderer.document(title:feedName:bodyHTML:css:)` and the 3-arg convenience overload are defined once in Task 1 Step 3 and used identically in Task 1 Step 5 (`ArticleDetailView`); Task 2 does not call `ArticleRenderer` at all, so there's no cross-task signature drift to check there.
