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

struct WebView: NSViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // transparent to match app
        webView.navigationDelegate = context.coordinator
        context.coordinator.attach(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
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
