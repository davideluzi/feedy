# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

This repository does not yet contain an Xcode project or any source code. It currently holds a single implementation plan:

`docs/superpowers/plans/2026-06-21-feedy-v1.md`

That plan is the authoritative spec for Feedy v1 — read it in full before starting work. It defines the file structure, the exact task-by-task build order (with TDD steps: failing test → run → implement → run), and the code for every file in the app. Follow it with `superpowers:subagent-driven-development` or `superpowers:executing-plans` as instructed at the top of the plan.

## What Feedy is

A native macOS RSS reader ("Feedy") with a Mail-style three-column UI: feed list, article list with read/unread state, and a consistently-styled article view.

**Tech stack:** Swift, SwiftUI, SwiftData (macOS 14+ deployment target), WKWebView, FeedKit (SPM) for RSS/Atom/JSON parsing, SwiftSoup (SPM) for HTML sanitization, XCTest.

## Commands (once the Xcode project exists)

- Build: `xcodebuild -scheme Feedy -destination 'platform=macOS' build`
- Run full test suite: `xcodebuild test -scheme Feedy -destination 'platform=macOS'`
- Run a single test class: `xcodebuild test -scheme Feedy -destination 'platform=macOS' -only-testing:FeedyTests/<TestClassName>`

The `.xcodeproj` itself must be created via the Xcode GUI (File ▸ New ▸ Project), not the CLI — see Task 1 of the plan. SPM dependencies (FeedKit, SwiftSoup) are added the same way, via File ▸ Add Package Dependencies.

## Architecture

The core principle: a pure, unit-testable domain layer sits behind protocols, fully decoupled from SwiftUI/SwiftData/networking, so feed parsing, HTML sanitization, article import, and rendering can all be tested without a UI or network access.

```
Feedy/
  FeedyApp.swift                 App entry, ModelContainer setup
  Models/                        SwiftData @Model entities (Feed, Article)
  Core/                          Pure/testable domain logic (see below)
  Views/                         SwiftUI views (NavigationSplitView, three columns)
  Resources/article.css          Single bundled stylesheet for all rendered articles
FeedyTests/
```

### Core layer (`Feedy/Core/`)

- **`ParsedTypes.swift`** — `ParsedFeed`/`ParsedArticle`: pure normalized value types, feed-format-agnostic.
- **`FeedParsing.swift`** — the `FeedParsing` protocol, plus `ArticleIdentity.key(for:)`: the article dedup key is `guid ?? link ?? hash(title+publishedDate)`.
- **`FeedKitParser.swift`** — the ONLY file that imports FeedKit. FeedKit's public API has drifted across major versions; if the installed version's API doesn't match, fix the mapping in this file only — the rest of the codebase depends solely on `ParsedFeed`/`ParsedArticle`.
- **`HTMLSanitizer.swift`** — the ONLY file that imports SwiftSoup (via the `HTMLSanitizing` protocol for injectability). Strips scripts/iframes/inline handlers, resolves relative URLs to absolute against the article's link, and produces both cleaned HTML and plain text. If the installed SwiftSoup names the allowlist type `Safelist` instead of `Whitelist`, that's the one line to change.
- **`ArticleImporter.swift`** — upserts parsed articles into SwiftData keyed by `ArticleIdentity`. The single most important invariant in the app: re-importing an existing article updates mutable fields but **never** touches `isRead`.
- **`ArticleRenderer.swift`** — wraps sanitized body HTML in one bundled `article.css` template so every article renders with identical typography, regardless of source feed.
- **`FeedFetching.swift`** / **`FeedRefreshService.swift`** — orchestrates fetch → parse → sanitize → import; a failed refresh records `Feed.lastErrorMessage` (health status) but never deletes existing articles. `refreshAll` runs with bounded concurrency (max 5 feeds at a time).

### Data model

- `Feed`: `url` is the unique key; tracks `lastFetchDate`/`lastErrorMessage` (nil = healthy) for the sidebar health indicator; cascade-deletes its `Article`s.
- `Article`: uniqueness is "identityKey within a feed", enforced by `ArticleImporter` in code — not a DB constraint, since the same guid can legitimately appear across different feeds.

### Rendering pipeline

Sanitize once at fetch time (persist cleaned HTML, not raw feed HTML) → `ArticleRenderer` wraps it in the bundled CSS template → a single `WKWebView` (`Views/WebView.swift`, `NSViewRepresentable`) renders it. Images load on the fly, not cached. Refresh happens on app launch and on demand (toolbar button / Cmd-R) only — no background refresh in v1.

### Sandbox requirement

The app target needs **Outgoing Connections (Client)** enabled under Signing & Capabilities ▸ App Sandbox, or feed fetches and article images will be silently blocked.

## Deferred (explicitly out of scope for v1)

Full-text extraction for truncated feeds, feed auto-discovery from a homepage URL, folders/groups, background refresh, full-text body search, image caching / tracking-pixel blocking, DB cleanup/pruning policy, favicon fetching. The architecture is intended to accommodate these later without rework — see the bottom of the plan doc for how each would plug in.
