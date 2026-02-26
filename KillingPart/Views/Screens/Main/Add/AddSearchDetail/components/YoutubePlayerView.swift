import SwiftUI
import UIKit
import WebKit

struct YoutubePlayerView: UIViewRepresentable {
    let videoURL: URL?
    let startSeconds: Double
    let endSeconds: Double

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.isUserInteractionEnabled = false
        webView.allowsLinkPreview = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard
            let videoURL,
            let videoID = extractVideoID(from: videoURL)
        else {
            return
        }

        let targetStart = normalizedSeconds(startSeconds)
        let targetEnd = max(normalizedSeconds(endSeconds), targetStart + 0.1)
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.lastSyncedStart = targetStart
            context.coordinator.lastSyncedEnd = targetEnd
            webView.loadHTMLString(
                makePlayerHTML(
                    videoID: videoID,
                    startSeconds: targetStart,
                    endSeconds: targetEnd
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
        guard !(isSameStart && isSameEnd) else { return }
        context.coordinator.lastSyncedStart = targetStart
        context.coordinator.lastSyncedEnd = targetEnd

        let targetStartJS = jsNumber(targetStart)
        let targetEndJS = jsNumber(targetEnd)
        webView.evaluateJavaScript(
            """
            window.kpDesiredStart = \(targetStartJS);
            window.kpDesiredEnd = \(targetEndJS);
            if (window.kpPlayerReady && window.kpPlayer) {
                if (window.kpApplyDesiredRange) {
                    window.kpApplyDesiredRange(true);
                } else {
                    window.kpPlayer.seekTo(window.kpDesiredStart, true);
                    window.kpPlayer.playVideo();
                }
            }
            """,
            completionHandler: nil
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var loadedVideoID: String?
        var lastSyncedStart: Double?
        var lastSyncedEnd: Double?
    }

    private var appRefererURL: URL? {
        guard let appRefererURLString else {
            return nil
        }
        return URL(string: appRefererURLString)
    }

    private func makePlayerHTML(videoID: String, startSeconds: Double, endSeconds: Double) -> String {
        let safeVideoID = escapeForJavaScript(videoID)
        let safeReferer = escapeForJavaScript(appRefererURLString ?? "")
        let initialStart = max(Int(startSeconds.rounded(.down)), 0)
        let initialStartJS = jsNumber(startSeconds)
        let initialEndJS = jsNumber(endSeconds)

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
                    pointer-events: none;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                window.kpDesiredStart = \(initialStartJS);
                window.kpDesiredEnd = \(initialEndJS);
                window.kpPlayer = null;
                window.kpPlayerReady = false;
                window.kpLoopTimer = null;

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

                    window.kpPlayer.playVideo();
                };

                window.kpStartRangeLoop = function() {
                    if (window.kpLoopTimer) {
                        clearInterval(window.kpLoopTimer);
                    }

                    window.kpLoopTimer = setInterval(function() {
                        if (!window.kpPlayerReady || !window.kpPlayer) {
                            return;
                        }

                        var state = Number(window.kpPlayer.getPlayerState ? window.kpPlayer.getPlayerState() : -1);
                        if (state !== 1 && state !== 3) {
                            return;
                        }

                        var targetStart = kpNormalizedStart();
                        var targetEnd = kpNormalizedEnd(targetStart);
                        var current = Number(window.kpPlayer.getCurrentTime ? window.kpPlayer.getCurrentTime() : targetStart);
                        if (isNaN(current) || current < targetStart || current >= targetEnd) {
                            window.kpPlayer.seekTo(targetStart, true);
                            window.kpPlayer.playVideo();
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
                            autoplay: 1,
                            controls: 0,
                            disablekb: 1,
                            fs: 0,
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
                                window.kpApplyDesiredRange(true);
                                window.kpStartRangeLoop();
                            },
                            onStateChange: function(event) {
                                if (Number(event.data) === 0) {
                                    window.kpApplyDesiredRange(true);
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
}
