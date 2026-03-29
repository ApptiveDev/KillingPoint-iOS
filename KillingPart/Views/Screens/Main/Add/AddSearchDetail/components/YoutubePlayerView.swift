import SwiftUI
import UIKit
import WebKit

struct YoutubePlayerView: UIViewRepresentable {
    @Environment(\.openURL) private var openURL

    let videoURL: URL?
    let startSeconds: Double
    let endSeconds: Double
    let isPlaying: Bool

    init(
        videoURL: URL?,
        startSeconds: Double,
        endSeconds: Double,
        isPlaying: Bool = true
    ) {
        self.videoURL = videoURL
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.isPlaying = isPlaying
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.isUserInteractionEnabled = true
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        let redirectOverlayButton = UIButton(type: .custom)
        redirectOverlayButton.translatesAutoresizingMaskIntoConstraints = false
        redirectOverlayButton.backgroundColor = .clear
        redirectOverlayButton.accessibilityLabel = "유튜브에서 열기"
        redirectOverlayButton.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleVideoTap),
            for: .touchUpInside
        )
        webView.addSubview(redirectOverlayButton)
        NSLayoutConstraint.activate([
            redirectOverlayButton.topAnchor.constraint(equalTo: webView.topAnchor),
            redirectOverlayButton.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
            redirectOverlayButton.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            redirectOverlayButton.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
        ])

        context.coordinator.openExternalURL = { targetURL in
            openURL(targetURL)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.openExternalURL = { targetURL in
            openURL(targetURL)
        }

        guard
            let videoURL,
            let videoID = extractVideoID(from: videoURL)
        else {
            context.coordinator.redirectURL = nil
            return
        }

        context.coordinator.redirectURL = makeWatchURL(videoID: videoID) ?? videoURL

        let targetStart = normalizedSeconds(startSeconds)
        let targetEnd = max(normalizedSeconds(endSeconds), targetStart + 0.1)
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.lastSyncedStart = targetStart
            context.coordinator.lastSyncedEnd = targetEnd
            context.coordinator.lastSyncedIsPlaying = isPlaying
            webView.loadHTMLString(
                makePlayerHTML(
                    videoID: videoID,
                    startSeconds: targetStart,
                    endSeconds: targetEnd,
                    shouldAutoplay: isPlaying
                ),
                baseURL: appRefererURL
            )
            return
        }

        let isSameStart = isApproximatelyEqual(
            context.coordinator.lastSyncedStart,
            targetStart
        )
        let isSameEnd = isApproximatelyEqual(
            context.coordinator.lastSyncedEnd,
            targetEnd
        )
        let isRangeChanged = !(isSameStart && isSameEnd)

        let isSamePlayState = context.coordinator.lastSyncedIsPlaying == isPlaying
        let isPlayStateChanged = !isSamePlayState
        guard isRangeChanged || isPlayStateChanged else { return }

        if isRangeChanged {
            context.coordinator.lastSyncedStart = targetStart
            context.coordinator.lastSyncedEnd = targetEnd
        }
        if isPlayStateChanged {
            context.coordinator.lastSyncedIsPlaying = isPlaying
        }

        let targetStartJS = jsNumber(targetStart)
        let targetEndJS = jsNumber(targetEnd)
        let shouldAutoplayJS = isPlaying ? "true" : "false"
        // Keep playback position when only play/pause state changes.
        // Force seek is only needed when the target range itself changed.
        let shouldForceSeekJS = isRangeChanged ? "true" : "false"
        let playbackControlJS = isPlaying
            ? """
            window.kpAutoplayAudioRestoreAttempted = false;
            if (window.kpApplyDesiredRange) {
                window.kpApplyDesiredRange(\(shouldForceSeekJS));
                if (window.kpScheduleAutoplayRetry) {
                    window.kpScheduleAutoplayRetry(\(shouldForceSeekJS));
                }
            } else {
                if (\(shouldForceSeekJS)) {
                    window.kpPlayer.seekTo(window.kpDesiredStart, true);
                }
                window.kpPlayer.playVideo();
            }
            """
            : """
            if (window.kpStopAutoplayRetry) {
                window.kpStopAutoplayRetry();
            }
            window.kpAutoplayMutedFallbackActive = false;
            window.kpAutoplayAudioRestoreAttempted = false;
            if (window.kpPlayer.unMute) {
                window.kpPlayer.unMute();
            }
            if (\(shouldForceSeekJS)) {
                window.kpPlayer.seekTo(window.kpDesiredStart, true);
            }
            window.kpPlayer.pauseVideo();
            """

        webView.evaluateJavaScript(
            """
            window.kpDesiredStart = \(targetStartJS);
            window.kpDesiredEnd = \(targetEndJS);
            window.kpShouldAutoplay = \(shouldAutoplayJS);
            if (window.kpPlayerReady && window.kpPlayer) {
                \(playbackControlJS)
            }
            """,
            completionHandler: nil
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var loadedVideoID: String?
        var lastSyncedStart: Double?
        var lastSyncedEnd: Double?
        var lastSyncedIsPlaying: Bool?
        var redirectURL: URL?
        var openExternalURL: ((URL) -> Void)?

        @objc
        func handleVideoTap() {
            openRedirectURL()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let isUserNavigation =
                navigationAction.navigationType == .linkActivated
                || navigationAction.navigationType == .formSubmitted
                || navigationAction.navigationType == .formResubmitted

            guard isUserNavigation else {
                decisionHandler(.allow)
                return
            }

            openRedirectURL()
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            openRedirectURL()
            return nil
        }

        private func openRedirectURL() {
            guard let redirectURL else { return }
            openExternalURL?(redirectURL)
        }
    }

    private var appRefererURL: URL? {
        guard let appRefererURLString else {
            return nil
        }
        return URL(string: appRefererURLString)
    }

    private func makePlayerHTML(
        videoID: String,
        startSeconds: Double,
        endSeconds: Double,
        shouldAutoplay: Bool
    ) -> String {
        let safeVideoID = escapeForJavaScript(videoID)
        let safeReferer = escapeForJavaScript(appRefererURLString ?? "")
        let initialStart = max(Int(startSeconds.rounded(.down)), 0)
        let initialStartJS = jsNumber(startSeconds)
        let initialEndJS = jsNumber(endSeconds)
        let initialShouldAutoplayJS = shouldAutoplay ? "true" : "false"
        let autoplayFlag = shouldAutoplay ? 1 : 0

        return """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    background: transparent;
                    overflow: hidden;
                }
                #player {
                    position: absolute;
                    inset: 0;
                    pointer-events: auto;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                window.kpDesiredStart = \(initialStartJS);
                window.kpDesiredEnd = \(initialEndJS);
                window.kpShouldAutoplay = \(initialShouldAutoplayJS);
                window.kpPlayer = null;
                window.kpPlayerReady = false;
                window.kpLoopTimer = null;
                window.kpAutoplayRetryTimer = null;
                window.kpAutoplayRetryCount = 0;
                window.kpAutoplayMaxRetryCount = 14;
                window.kpAutoplayRetryDelayMs = 220;
                window.kpAutoplayMuteFallbackAfterCount = 3;
                window.kpAutoplayMutedFallbackActive = false;
                window.kpAutoplayAudioRestoreAttempted = false;

                window.kpStopAutoplayRetry = function() {
                    if (window.kpAutoplayRetryTimer) {
                        clearTimeout(window.kpAutoplayRetryTimer);
                        window.kpAutoplayRetryTimer = null;
                    }
                    window.kpAutoplayRetryCount = 0;
                };

                function kpNormalizedStart() {
                    var targetStart = Number(window.kpDesiredStart || 0);
                    if (isNaN(targetStart) || targetStart < 0) {
                        targetStart = 0;
                    }
                    return targetStart;
                }

                function kpNormalizedEnd(targetStart) {
                    var targetEnd = Number(window.kpDesiredEnd || targetStart);
                    if (isNaN(targetEnd)) {
                        targetEnd = targetStart;
                    }
                    if (targetEnd <= targetStart) {
                        targetEnd = targetStart + 0.1;
                    }
                    return targetEnd;
                }

                window.kpApplyDesiredRange = function(forceSeek) {
                    if (!window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }

                    var targetStart = kpNormalizedStart();
                    var targetEnd = kpNormalizedEnd(targetStart);
                    var current = Number(window.kpPlayer.getCurrentTime ? window.kpPlayer.getCurrentTime() : targetStart);

                    if (isNaN(current) || forceSeek || current < targetStart || current >= targetEnd) {
                        window.kpPlayer.seekTo(targetStart, true);
                    }

                    if (window.kpAutoplayMutedFallbackActive && window.kpPlayer.mute) {
                        window.kpPlayer.mute();
                    }
                    window.kpPlayer.playVideo();
                };

                window.kpScheduleAutoplayRetry = function(forceSeek) {
                    if (!window.kpShouldAutoplay || !window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }
                    if (window.kpAutoplayRetryTimer) {
                        return;
                    }
                    if (window.kpAutoplayRetryCount >= window.kpAutoplayMaxRetryCount) {
                        return;
                    }

                    window.kpAutoplayRetryTimer = setTimeout(function() {
                        window.kpAutoplayRetryTimer = null;
                        if (!window.kpShouldAutoplay || !window.kpPlayerReady || !window.kpPlayer) {
                            return;
                        }

                        window.kpApplyDesiredRange(forceSeek);

                        var state = Number(window.kpPlayer.getPlayerState ? window.kpPlayer.getPlayerState() : -1);
                        if (state === 1 || state === 3) {
                            window.kpAutoplayRetryCount = 0;
                            return;
                        }

                        window.kpAutoplayRetryCount += 1;
                        if (
                            !window.kpAutoplayMutedFallbackActive
                            && window.kpAutoplayRetryCount >= window.kpAutoplayMuteFallbackAfterCount
                        ) {
                            window.kpAutoplayMutedFallbackActive = true;
                            window.kpAutoplayAudioRestoreAttempted = false;
                        }
                        window.kpScheduleAutoplayRetry(false);
                    }, window.kpAutoplayRetryDelayMs);
                };

                window.kpStartRangeLoop = function() {
                    if (window.kpLoopTimer) {
                        clearInterval(window.kpLoopTimer);
                    }

                    window.kpLoopTimer = setInterval(function() {
                        if (!window.kpPlayerReady || !window.kpPlayer) {
                            return;
                        }

                        if (!window.kpShouldAutoplay) {
                            return;
                        }

                        var state = Number(window.kpPlayer.getPlayerState ? window.kpPlayer.getPlayerState() : -1);
                        if (state === 1 || state === 3) {
                            var targetStart = kpNormalizedStart();
                            var targetEnd = kpNormalizedEnd(targetStart);
                            var current = Number(window.kpPlayer.getCurrentTime ? window.kpPlayer.getCurrentTime() : targetStart);
                            if (isNaN(current) || current < targetStart || current >= targetEnd) {
                                window.kpPlayer.seekTo(targetStart, true);
                                window.kpPlayer.playVideo();
                            }
                            return;
                        }

                        if (state === 0 || state === 2 || state === 5 || state === -1) {
                            window.kpScheduleAutoplayRetry(false);
                        }
                    }, 200);
                };

                var tag = document.createElement('script');
                tag.src = 'https://www.youtube.com/iframe_api';
                document.head.appendChild(tag);

                window.onYouTubeIframeAPIReady = function() {
                    window.kpPlayer = new YT.Player('player', {
                        width: '100%',
                        height: '100%',
                        videoId: '\(safeVideoID)',
                        playerVars: {
                            autoplay: \(autoplayFlag),
                            controls: 1,
                            disablekb: 0,
                            fs: 1,
                            rel: 0,
                            modestbranding: 1,
                            iv_load_policy: 3,
                            playsinline: 1,
                            start: \(initialStart),
                            origin: '\(safeReferer)',
                            widget_referrer: '\(safeReferer)'
                        },
                        events: {
                            onReady: function() {
                                window.kpPlayerReady = true;
                                window.kpAutoplayMutedFallbackActive = false;
                                window.kpAutoplayAudioRestoreAttempted = false;
                                if (window.kpShouldAutoplay) {
                                    window.kpApplyDesiredRange(true);
                                    window.kpStartRangeLoop();
                                    window.kpScheduleAutoplayRetry(true);
                                } else {
                                    if (window.kpPlayer.unMute) {
                                        window.kpPlayer.unMute();
                                    }
                                    window.kpPlayer.seekTo(window.kpDesiredStart, true);
                                    window.kpPlayer.pauseVideo();
                                }
                            },
                            onStateChange: function(event) {
                                var state = Number(event.data);
                                if (!window.kpShouldAutoplay) {
                                    return;
                                }

                                if (state === 1 || state === 3) {
                                    window.kpStopAutoplayRetry();
                                    if (
                                        window.kpAutoplayMutedFallbackActive
                                        && !window.kpAutoplayAudioRestoreAttempted
                                    ) {
                                        window.kpAutoplayAudioRestoreAttempted = true;
                                        setTimeout(function() {
                                            if (
                                                !window.kpShouldAutoplay
                                                || !window.kpPlayer
                                                || !window.kpPlayer.unMute
                                            ) {
                                                return;
                                            }

                                            window.kpPlayer.unMute();

                                            var stateAfterUnmute = Number(
                                                window.kpPlayer.getPlayerState
                                                    ? window.kpPlayer.getPlayerState()
                                                    : -1
                                            );
                                            if (stateAfterUnmute === 1 || stateAfterUnmute === 3) {
                                                window.kpAutoplayMutedFallbackActive = false;
                                                return;
                                            }

                                            if (window.kpPlayer.mute) {
                                                window.kpPlayer.mute();
                                            }
                                            window.kpPlayer.playVideo();
                                        }, 160);
                                    }
                                    return;
                                }

                                if (state === 0) {
                                    window.kpApplyDesiredRange(true);
                                    window.kpScheduleAutoplayRetry(true);
                                    return;
                                }

                                if (state === 2 || state === 5 || state === -1) {
                                    window.kpScheduleAutoplayRetry(false);
                                }
                            }
                        }
                    });
                };

                window.addEventListener('beforeunload', function() {
                    if (window.kpLoopTimer) {
                        clearInterval(window.kpLoopTimer);
                        window.kpLoopTimer = null;
                    }
                    if (window.kpAutoplayRetryTimer) {
                        clearTimeout(window.kpAutoplayRetryTimer);
                        window.kpAutoplayRetryTimer = null;
                    }
                });
            </script>
        </body>
        </html>
        """
    }

    private func extractVideoID(from url: URL) -> String? {
        let pathComponents = url.path.split(separator: "/").map(String.init)
        if let embedIndex = pathComponents.firstIndex(of: "embed"),
           pathComponents.indices.contains(embedIndex + 1) {
            let candidate = pathComponents[embedIndex + 1]
            if !candidate.isEmpty {
                return candidate
            }
        }

        if let shortsIndex = pathComponents.firstIndex(of: "shorts"),
           pathComponents.indices.contains(shortsIndex + 1) {
            let candidate = pathComponents[shortsIndex + 1]
            if !candidate.isEmpty {
                return candidate
            }
        }

        if let liveIndex = pathComponents.firstIndex(of: "live"),
           pathComponents.indices.contains(liveIndex + 1) {
            let candidate = pathComponents[liveIndex + 1]
            if !candidate.isEmpty {
                return candidate
            }
        }

        if
            let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host?.lowercased(),
            host.contains("youtu.be"),
            let firstPath = pathComponents.first,
            !firstPath.isEmpty
        {
            return firstPath
        }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value,
           !v.isEmpty {
            return v
        }

        return nil
    }

    private func escapeForJavaScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
    }

    private var appRefererURLString: String? {
        guard
            let bundleID = Bundle.main.bundleIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !bundleID.isEmpty
        else {
            return nil
        }

        return "https://\(bundleID.lowercased())"
    }

    private func normalizedSeconds(_ value: Double) -> Double {
        let safe = max(value, 0)
        return (safe * 1000).rounded() / 1000
    }

    private func isApproximatelyEqual(_ lhs: Double?, _ rhs: Double) -> Bool {
        guard let lhs else { return false }
        return abs(lhs - rhs) < 0.001
    }

    private func jsNumber(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    private func makeWatchURL(videoID: String) -> URL? {
        guard !videoID.isEmpty else { return nil }
        var components = URLComponents(string: "https://www.youtube.com/watch")
        components?.queryItems = [URLQueryItem(name: "v", value: videoID)]
        return components?.url
    }
}
