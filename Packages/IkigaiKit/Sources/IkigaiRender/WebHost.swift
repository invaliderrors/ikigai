import AppKit
import OSLog
import WebKit

/// A web wallpaper in a locked-down web view: it can read only its own package, has no network,
/// can't play sound, and truly stops while paused. Pages can listen for `ikigai:pause` / `ikigai:resume`.
@MainActor public final class WebHost: NSObject, WallpaperHost, WKNavigationDelegate {
    public let view = NSView()
    private let webView: WKWebView
    private let snapshot = NSImageView()
    private let package: URL
    private var playing = true
    private var loaded = false

    // Two rules, not one: WebKit's url-filter regex doesn't support alternation like (https?|wss?).
    private static let blockNetwork = #"""
        [{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}},
         {"trigger":{"url-filter":"^wss?://"},"action":{"type":"block"}}]
        """#

    /// Content rules don't cover WebRTC (STUN/TURN over UDP), so remove it before any page script runs.
    private static let removeWebRTC = WKUserScript(source: """
        for (const name of ['RTCPeerConnection', 'webkitRTCPeerConnection', 'RTCDataChannel']) {
          try { delete window[name]; Object.defineProperty(window, name, { value: undefined, configurable: false }); } catch (e) {}
        }
        """, injectionTime: .atDocumentStart, forMainFrameOnly: false)

    public init(page: URL, package: URL) {
        self.package = package.standardizedFileURL
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        // Muted video may autoplay; anything audible needs a user gesture, which never reaches the desktop.
        config.mediaTypesRequiringUserActionForPlayback = .audio
        config.userContentController.addUserScript(Self.removeWebRTC)
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self

        for subview in [snapshot, webView] as [NSView] {
            subview.frame = view.bounds
            subview.autoresizingMask = [.width, .height]
            view.addSubview(subview)
        }
        snapshot.imageScaling = .scaleAxesIndependently

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

    /// True once the page has finished loading, false if it didn't within the timeout (or never will,
    /// when the network rules failed to compile).
    public func waitUntilLoaded(timeout: Duration) async -> Bool {
        // shortcut: polls every 100 ms; fine for one-off previews, use a continuation if anything hot needs it.
        let deadline = ContinuousClock.now + timeout
        while !loaded, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return loaded
    }

    public func snapshot() async -> NSImage? {
        try? await webView.takeSnapshot(configuration: nil)
    }

    public func setPlaying(_ playing: Bool) {
        guard playing != self.playing else { return }
        self.playing = playing
        if loaded { apply() }  // otherwise applied when the page finishes loading
    }

    /// Paused: freeze a snapshot on screen and hide the web view, which makes WebKit stop
    /// requestAnimationFrame and throttle timers, so the page costs (almost) nothing.
    private func apply() {
        let playing = playing
        webView.setAllMediaPlaybackSuspended(!playing)
        webView.evaluateJavaScript("document.dispatchEvent(new Event('ikigai:\(playing ? "resume" : "pause")'))")
        if playing {
            webView.isHidden = false
            snapshot.image = nil
        } else {
            webView.takeSnapshot(with: nil) { [weak self] image, _ in
                MainActor.assumeIsolated {
                    guard let self, !self.playing else { return }
                    self.snapshot.image = image
                    self.webView.isHidden = true
                }
            }
        }
    }

    // MARK: WKNavigationDelegate

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded = true
        if !playing { apply() }
    }

    /// Only files inside the package may load; links and redirects elsewhere are refused.
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        let inside = url.isFileURL && url.standardizedFileURL.path.hasPrefix(package.path + "/")
        decisionHandler(inside || url.absoluteString == "about:blank" ? .allow : .cancel)
    }
}
