# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Current state

Feedy v1 is built and feature-complete: a native macOS RSS reader with a Mail-style three-column UI (sidebar of feeds → article list with read/unread state and search → a rendered article pane), add/delete feed, launch-time and on-demand refresh, and a pure, unit-tested domain layer. The original implementation plan is preserved at:

`docs/superpowers/plans/2026-06-21-feedy-v1.md`

It's still useful as historical context on the intended design and task-by-task build order, but treat the actual source under `Feedy/` as authoritative where the two disagree — several details (notably the FeedKit API, see below) drifted from what the plan assumed. There is no further plan-execution work outstanding; changes now are ordinary feature/bugfix work on an existing app. Read this file plus the relevant source files before making changes, same as any established codebase.

## What Feedy is

A native macOS RSS reader ("Feedy") with a Mail-style three-column UI: feed list, article list with read/unread state, and a consistently-styled article view.

**Tech stack:** Swift, SwiftUI, SwiftData (macOS 15.0+ deployment target — raised from 14 for the `Translation` framework, which requires 15.0), WKWebView, FeedKit 10.4 (SPM) for RSS/Atom/JSON parsing, SwiftSoup (SPM) for HTML sanitization, Apple's `Translation` framework for on-device article translation, XCTest.

## Commands

Run from `/Users/davide/GitHub/feedy/Feedy` (the directory containing `Feedy.xcodeproj`):

- Build: `xcodebuild -scheme Feedy -destination 'platform=macOS' build`
- Run full test suite: `xcodebuild test -scheme Feedy -destination 'platform=macOS'`
- Run a single test class: `xcodebuild test -scheme Feedy -destination 'platform=macOS' -only-testing:FeedyTests/<TestClassName>`

The `.xcodeproj` and its SPM dependencies (FeedKit, SwiftSoup) already exist and are checked in; there's normally no need to touch them via the Xcode GUI. The app target and `FeedyTests` both use file-system-synchronized groups (`PBXFileSystemSynchronizedRootGroup`) for their Swift sources, so new `.swift` files (and new test fixtures under `FeedyTests/Fixtures/`) dropped into the right directory are picked up automatically — no `project.pbxproj` edits needed for those. `project.pbxproj` edits are only required for things sync groups don't cover: new package dependencies, build settings, target membership changes for non-source files, etc.

## Architecture

The core principle: a pure, unit-testable domain layer sits behind protocols, fully decoupled from SwiftUI/SwiftData/networking, so feed parsing, HTML sanitization, article import, and rendering can all be tested without a UI or network access.

Real repo layout (paths relative to `Feedy/`, i.e. `Feedy/Feedy/...` and `Feedy/FeedyTests/...` from the repo root):

```
Feedy/                            Xcode project root (contains Feedy.xcodeproj)
  Feedy/
    FeedyApp.swift                 App entry, ModelContainer setup
    ContentView.swift              Three-column NavigationSplitView shell
    Models/                        SwiftData @Model entities (Feed, Article)
    Core/                          Pure/testable domain logic (see below)
    Views/                         SwiftUI views (Sidebar, ArticleList, ArticleDetail, WebView, AddFeedSheet, Selection)
    Resources/article.css          Single bundled stylesheet for all rendered articles
    Feedy.entitlements             App Sandbox + outgoing-network entitlements (see below)
  FeedyTests/
    Fixtures/                      Sample feed XML and dirty-HTML fixtures used by tests
```

Note `ContentView.swift` and `FeedyApp.swift` sit directly under `Feedy/Feedy/`, not under `Views/` — that placement is a known minor inconsistency, left as-is (out of scope for routine fixes; don't "clean it up" as a drive-by).

### Core layer (`Feedy/Feedy/Core/`)

- **`ParsedTypes.swift`** — `ParsedFeed`/`ParsedArticle`: pure normalized value types, feed-format-agnostic.
- **`FeedParsing.swift`** — the `FeedParsing` protocol, plus `ArticleIdentity.key(for:)`: the article dedup key is `guid ?? link ?? hash(title+publishedDate)`.
- **`FeedKitParser.swift`** — the ONLY file that imports FeedKit. See "FeedKit 10.4 API drift" below for exactly how the real API differs from what the plan assumed. If a future FeedKit upgrade changes the API again, fix the mapping in this file only — the rest of the codebase depends solely on `ParsedFeed`/`ParsedArticle`. `mapRSS`/`mapAtom`/`mapJSON` are covered by tests in `FeedyTests/FeedKitParserTests.swift` (RSS and Atom fixtures under `FeedyTests/Fixtures/`); JSON Feed mapping is currently untested.
- **`HTMLSanitizer.swift`** — one of two files that import SwiftSoup (via the `HTMLSanitizing` protocol for injectability; see `ArticleTranslator.swift` below for the other). Strips scripts/iframes/inline handlers, resolves relative URLs to absolute against the article's link, and produces both cleaned HTML and plain text. If the installed SwiftSoup names the allowlist type `Safelist` instead of `Whitelist`, that's the one line to change.
- **`ArticleImporter.swift`** — upserts parsed articles into SwiftData keyed by `ArticleIdentity`. The single most important invariant in the app: re-importing an existing article updates mutable fields but **never** touches `isRead`.
- **`ArticleRenderer.swift`** — wraps sanitized body HTML in one bundled `article.css` template so every article renders with identical typography, regardless of source feed. Also layers in the user's chosen font size (`Views/ArticleDetailView.swift`'s toolbar A-/A+ buttons and Cmd-+/Cmd--/Cmd-0) as a second `<style>` tag, overriding the CSS default on the cascade.
- **`ArticleTranslator.swift`** — the other file that imports SwiftSoup. Walks the DOM of already-sanitized article HTML and translates only text-node content (leaving tags/links/images untouched), via the injectable `TextBatchTranslating` protocol — kept import-agnostic so it's unit-testable without Apple's `Translation` framework. The concrete adapter that wraps a live `TranslationSession` (`SessionTextTranslator`) lives in `Views/ArticleDetailView.swift` instead, because `TranslationSession` can only be obtained through SwiftUI's `.translationTask` view modifier, tied to view lifecycle — there's no headless/Core-layer way to construct one pre-macOS 26. Translation is English→Italian only (hardcoded), triggered by a toolbar button, and is not persisted — it's re-run (once, then cached in view state) each time an article is opened and translation is requested.
- **`FeedFetching.swift`** / **`FeedRefreshService.swift`** — orchestrates fetch → parse → sanitize → import; a failed refresh records `Feed.lastErrorMessage` (health status) but never deletes existing articles. `refreshAll` runs with bounded concurrency (max 5 feeds at a time). Note: parsing/sanitization currently run on the main thread inside this service — a known perf issue for large feeds/many feeds, tracked as a follow-up, not yet fixed.

`Views/AddFeedSheet.swift` also does its own fetch → parse → import for the single feed being added (pre-checking for an already-subscribed URL first), rather than going through `FeedRefreshService` — keep that in mind if you change the shared import/refresh contract, since both call sites need to stay consistent (in particular: newly-added feeds must have their articles imported immediately, not just on the next refresh).

### Data model

- `Feed`: `url` is the unique key (`@Attribute(.unique)`); tracks `lastFetchDate`/`lastErrorMessage` (nil = healthy) for the sidebar health indicator; cascade-deletes its `Article`s. `faviconURL` exists on the model but is currently unused/inert (favicon fetching is deferred, see below).
- `Article`: uniqueness is "identityKey within a feed", enforced by `ArticleImporter` in code — not a DB constraint, since the same guid can legitimately appear across different feeds. `fetchedAt` exists but is currently unused/inert.

### Rendering pipeline

Sanitize once at fetch time (persist cleaned HTML, not raw feed HTML) → `ArticleRenderer` wraps it in the bundled CSS template → a single `WKWebView` (`Views/WebView.swift`, `NSViewRepresentable`) renders it. The `WebView`'s `Coordinator` guards `loadHTMLString` behind an "only reload if the HTML actually changed" check (unrelated SwiftData saves elsewhere in the app re-evaluate the view tree constantly and would otherwise reset scroll position on every save), and its `WKNavigationDelegate` routes user-clicked links (`.linkActivated`) out to `NSWorkspace.shared.open(url)` rather than navigating the embedded web view in place. Images load on the fly, not cached. Refresh happens on app launch and on demand (toolbar button / Cmd-R) only — no background refresh in v1.

### Sandbox requirement

The app target's sandboxing is configured via a committed entitlements file, not the Xcode GUI toggle: `Feedy/Feedy/Feedy.entitlements` sets `com.apple.security.app-sandbox` and `com.apple.security.network.client` to `true`, and the target's `CODE_SIGN_ENTITLEMENTS` build setting in `Feedy.xcodeproj/project.pbxproj` points at that file. `network.client` ("Outgoing Connections (Client)") is what allows feed fetches and article images through the sandbox — without it they're silently blocked. If you ever need to inspect/change sandbox capabilities, edit `Feedy.entitlements` directly rather than looking for a Signing & Capabilities checkbox to toggle (the checkbox is just a GUI view onto the same file).

### FeedKit 10.4 API drift (vs. what the plan assumed)

The plan was written against an assumed FeedKit API (`FeedParser(data:).parse()` returning `Result<Feed, ParserError>`). The version actually pinned in this project, **FeedKit 10.4.0** (`upToNextMajorVersion` from 10.4.0, see `project.pbxproj`), has a materially different, real API:

- Parsing is synchronous and throwing: `try FeedKit.Feed(data: data)`, not `FeedParser(data:).parse()` + `Result` unwrapping.
- `FeedKit.Feed` is an `enum` with `.rss(RSSFeed)`, `.atom(AtomFeed)`, `.json(JSONFeed)` cases — you switch on it, rather than inspecting a `feedType` property.
- FeedKit 10.4 depends on a separate `XMLKit` product from the *same* package; the Xcode target must link both `FeedKit` and `XMLKit` (both already declared as package product dependencies in `project.pbxproj` — if you ever re-add the package from scratch, remember to add both, not just `FeedKit`).
- Atom link resolution needs a small helper (`FeedKitParser.alternateLink`) since an Atom `<entry>`/`<feed>` can have multiple `<link>` elements; it prefers `rel="alternate"` and falls back to the first link with an `href`.

All of this is isolated to `Feedy/Feedy/Core/FeedKitParser.swift` per the "only file that imports FeedKit" rule above — if FeedKit's API drifts again on a future upgrade, that's the only file that should need to change, and `FeedyTests/FeedKitParserTests.swift` (RSS + Atom coverage) plus the fixtures in `FeedyTests/Fixtures/` are the regression net for it.

## Deferred (explicitly out of scope for v1)

Full-text extraction for truncated feeds, feed auto-discovery from a homepage URL, folders/groups, background refresh, full-text body search, image caching / tracking-pixel blocking, DB cleanup/pruning policy, favicon fetching. The architecture is intended to accommodate these later without rework — see the bottom of the plan doc for how each would plug in.
