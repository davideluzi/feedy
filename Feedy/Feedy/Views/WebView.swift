import SwiftUI
import WebKit
import AppKit

/// Spins up a WebContent process ahead of time (at app launch, before any article is
/// selected) so the first real article WKWebView doesn't pay a cold-start process-launch
/// delay. As of macOS 12, all WKWebViews in a process implicitly share one WebContent
/// process pool, so this dummy load is enough to warm the one the real WebView will use too.
@MainActor
enum WebKitWarmer {
    private static var warmupWebView: WKWebView?

    static func warm() {
        guard warmupWebView == nil else { return }
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.loadHTMLString("", baseURL: nil)
        // WebKit swaps to a fresh WebContent process the first time a WKWebView instance
        // navigates across origins (Process Swap on Navigation), then keeps a spare process
        // pre-warmed for future swaps. Force that first swap here, against a throwaway
        // origin, so it doesn't happen on the user's second article click instead.
        webView.loadHTMLString("", baseURL: URL(string: "https://warmup.invalid/"))
        warmupWebView = webView
    }
}

/// WKWebView overrides NSView's `menu(for:)` internally to show its own native context menu
/// (Reload, Inspect Element, ...), which swallows right-clicks before SwiftUI's .contextMenu
/// ever sees them and before any WKUIDelegate hook gets a say (those are iOS-only). Control-click
/// goes through `mouseDown`'s modifier check and reaches `menu(for:)` fine, but a genuine
/// right-click — physical mouse button or trackpad two-finger secondary click, both delivered as
/// `.rightMouseDown` — is handled by WKWebView's own `rightMouseDown(with:)` override, which
/// shows its native menu directly without ever consulting `menu(for:)`. Overriding both, without
/// calling super, is what it takes to fully replace it.
final class ArticleWKWebView: WKWebView {
    var isRead = false
    var link: String?
    var onToggleRead: (() -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        buildContextMenu()
    }

    override func rightMouseDown(with event: NSEvent) {
        NSMenu.popUpContextMenu(buildContextMenu(), with: event, for: self)
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: isRead ? "Mark as Unread" : "Mark as Read",
                                     action: #selector(toggleRead), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        if link != nil {
            let copyItem = NSMenuItem(title: "Copy Link", action: #selector(copyLink), keyEquivalent: "")
            copyItem.target = self
            menu.addItem(copyItem)
        }

        return menu
    }

    @objc private func toggleRead() {
        onToggleRead?()
    }

    @objc private func copyLink() {
        guard let link else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(link, forType: .string)
    }
}

struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    let isRead: Bool
    let link: String?
    let onToggleRead: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> ArticleWKWebView {
        let config = WKWebViewConfiguration()
        let webView = ArticleWKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // transparent to match app
        webView.navigationDelegate = context.coordinator
        context.coordinator.attach(webView)
        return webView
    }

    func updateNSView(_ webView: ArticleWKWebView, context: Context) {
        webView.isRead = isRead
        webView.link = link
        webView.onToggleRead = onToggleRead

        // Only reload when the content actually changed; SwiftUI re-evaluates this view
        // on every unrelated model save (mark-as-read, refresh, etc.), and an unconditional
        // reload would reset the reader's scroll position each time.
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedHTML: String?
        private weak var webView: WKWebView?

        override init() {
            super.init()
            // macOS can suspend/terminate WKWebView's WebContent process while the app is
            // backgrounded. Poking it with a no-op JS eval as soon as the app is foregrounded
            // again wakes that process ahead of time, so the next article click doesn't pay
            // the relaunch latency.
            NotificationCenter.default.addObserver(self,
                                                    selector: #selector(appDidBecomeActive),
                                                    name: NSApplication.didBecomeActiveNotification,
                                                    object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        @objc private func appDidBecomeActive() {
            webView?.evaluateJavaScript("null", completionHandler: nil)
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow the programmatic loadHTMLString(_:baseURL:) load (navigationType == .other).
            // Anything the user clicks (.linkActivated) should open in the default browser
            // instead of navigating the in-app WebView, which has no chrome or way back.
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
