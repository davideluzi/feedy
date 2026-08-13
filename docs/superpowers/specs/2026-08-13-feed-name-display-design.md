# Feed name display — design

Date: 2026-08-13
Status: Approved

## Problem

Feedy already captures a feed's name automatically at add time (`Feed.title`,
set in `AddFeedSheet.swift` from the parsed feed/channel title — RSS
`<channel><title>`, Atom `<feed><title>`, or JSON Feed `title`), but that name
is never shown next to the articles that belong to it. The article list and
the article detail view both jump straight to the article title, with no
indication of which feed it came from.

## Goal

Show the feed's name above the article title in both places:

1. Every row of the article list (`ArticleListView.ArticleRow`).
2. The rendered article document in the detail view (`ArticleRenderer` /
   `article.css`, inside the `WKWebView`).

## Non-goals

- No change to feed name *acquisition*. `Feed.title` already comes from the
  parsed feed's own title at add time; this design does not add homepage
  HTML `<title>` scraping or any other new fetch.
- No schema changes to `Feed` or `Article` — `Article.feed?.title` is already
  reachable via the existing SwiftData relationship.
- No change to `FeedRefreshService` / `ArticleImporter` behavior.

## Design

### 1. Article list — `Views/ArticleListView.swift`

`ArticleRow` gains a small caption line above the title, shown
unconditionally (in every context — "All Articles" and single-feed views
alike, per explicit product decision to keep the row layout uniform rather
than branch on the current sidebar selection):

```swift
if let feedName = article.feed?.title, !feedName.isEmpty {
    Text(feedName).font(.caption2).foregroundStyle(.secondary)
}
Text(article.title).font(.headline).lineLimit(2)
```

The `!feedName.isEmpty` guard also covers the (only-in-tests-today) edge
case of an `Article` constructed without a `feed`.

### 2. Article detail — `Core/ArticleRenderer.swift` + `Resources/article.css`

The feed name is rendered as part of the sanitized HTML document (not as a
native SwiftUI element outside the `WKWebView`), so it shares the same
typography system as the rest of the article via `article.css`.

`ArticleRenderer.document` gains a `feedName: String?` parameter, inserted
as a `<p class="feed-name">` immediately before the `<h1>` title. It is
escaped through the same `escape()` helper already used for the title, since
feed names originate from external, untrusted feed content:

```swift
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

static func document(title: String, feedName: String?, bodyHTML: String) -> String {
    document(title: title, feedName: feedName, bodyHTML: bodyHTML, css: loadCSS())
}
```

`article.css` gets one new rule, styled consistently with the existing muted
caption treatment used for `figcaption`:

```css
.feed-name {
  color: var(--muted); font-size: 0.85em; font-weight: 600;
  text-transform: uppercase; letter-spacing: 0.02em; margin: 0 0 0.4em;
}
```

`Views/ArticleDetailView.swift` updates its call site to pass
`feedName: article.feed?.title`.

## Testing

- `FeedyTests/ArticleRendererTests.swift`: update the existing two tests for
  the new `feedName` parameter, and add coverage that:
  - a non-nil feed name renders `<p class="feed-name">…</p>` before `<h1>`;
  - a nil feed name renders no `.feed-name` element at all;
  - the feed name is HTML-escaped the same way the title is.
- No new tests for `ArticleRow` — the view layer has no existing test
  coverage today, and this change doesn't introduce a testable pure
  function, consistent with the rest of `Views/`.

## Rollout / risk

Small, additive, no data migration. The only breaking signature change is
`ArticleRenderer.document`, whose two call sites (`ArticleDetailView.swift`
and `ArticleRendererTests.swift`) are both updated in the same change.
