import AppKit
import OSLog
import WebKit

/// A web wallpaper in a locked-down web view: it can read only its own package and
/// has no network access. Pages can listen for `ikigai:pause` / `ikigai:resume` on `document`.
@MainActor public final class WebHost: WallpaperHost {
    private let webView: WKWebView
    public var view: NSView { webView }

    private static let blockNetwork = #"[{"trigger":{"url-filter":"^(https?|wss?)://"},"action":{"type":"block"}}]"#

    public init(page: URL, package: URL) {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)

        // Load only once the blocking rules are in place, so the page never gets a network window.
        Task { [webView] in
            do {
                let rules = try await WKContentRuleListStore.default()
                    .compileContentRuleList(forIdentifier: "ikigai.block-network", encodedContentRuleList: Self.blockNetwork)
                guard let rules else { throw CocoaError(.featureUnsupported) }
                webView.configuration.userContentController.add(rules)
                webView.loadFileURL(page, allowingReadAccessTo: package)
            } catch {
                // No rules, no page: failing closed beats loading with network access.
                Logger(subsystem: "com.invaliderrors.ikigai", category: "web").error("Web wallpaper not loaded: \(error)")
            }
        }
    }

    public func setPlaying(_ playing: Bool) {
        webView.setAllMediaPlaybackSuspended(!playing)
        webView.evaluateJavaScript("document.dispatchEvent(new Event('ikigai:\(playing ? "resume" : "pause")'))")
    }
}
