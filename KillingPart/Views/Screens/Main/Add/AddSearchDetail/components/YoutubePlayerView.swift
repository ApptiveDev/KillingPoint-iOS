import SwiftUI
import UIKit
import WebKit

struct YoutubePlaybackProgress: Equatable {
    let currentSeconds: Double
    let startSeconds: Double
    let endSeconds: Double
    let isInsideRange: Bool

    var elapsedInRange: Double {
        min(max(currentSeconds - startSeconds, 0), max(endSeconds - startSeconds, 0))
    }
}

struct YoutubePlaybackRange: Equatable {
    let startSeconds: Double
    let endSeconds: Double

    init(startSeconds: Double, endSeconds: Double) {
        let normalizedStart = Self.normalizedSeconds(startSeconds)
        self.startSeconds = normalizedStart
        self.endSeconds = max(Self.normalizedSeconds(endSeconds), normalizedStart + 0.1)
    }

    var duration: Double {
        max(endSeconds - startSeconds, 0)
    }

    func contains(_ currentSeconds: Double, tolerance: Double = 0.08) -> Bool {
        currentSeconds >= startSeconds - tolerance && currentSeconds < endSeconds - tolerance
    }

    private static func normalizedSeconds(_ value: Double) -> Double {
        let safe = max(value, 0)
        return (safe * 1000).rounded() / 1000
    }
}

struct YoutubePlayerAutoplayPolicy: Equatable {
    let mutedFallbackDelay: TimeInterval

    static let `default` = YoutubePlayerAutoplayPolicy(mutedFallbackDelay: 1.2)

    func shouldUseMutedFallback(
        allowsMutedAutoplayFallback: Bool,
        hasUsedMutedFallback: Bool,
        hasUserInteracted: Bool,
        elapsedSinceUnmutedAttempt: TimeInterval
    ) -> Bool {
        allowsMutedAutoplayFallback
            && !hasUsedMutedFallback
            && !hasUserInteracted
            && elapsedSinceUnmutedAttempt >= mutedFallbackDelay
    }
}

struct YoutubePlayerView: UIViewRepresentable {
    enum PlaybackState: String, Equatable {
        case unstarted
        case playing
        case paused
        case buffering
        case ended
        case stalled
    }

    @Environment(\.openURL) private var openURL

    let videoURL: URL?
    let startSeconds: Double
    let endSeconds: Double
    let isPlaying: Bool
    let playbackFocusToken: Int
    let shouldLoopPlayback: Bool
    let allowsMutedAutoplayFallback: Bool
    let respectsUserInteraction: Bool
    let showsMutedFallbackControl: Bool
    let onPlaybackEnded: (() -> Void)?
    let onPlaybackStateChanged: ((PlaybackState) -> Void)?
    let onPlaybackProgressChanged: ((YoutubePlaybackProgress) -> Void)?

    init(
        videoURL: URL?,
        startSeconds: Double,
        endSeconds: Double,
        isPlaying: Bool = true,
        playbackFocusToken: Int = 0,
        shouldLoopPlayback: Bool = true,
        allowsMutedAutoplayFallback: Bool = true,
        respectsUserInteraction: Bool = true,
        showsMutedFallbackControl: Bool = true,
        onPlaybackEnded: (() -> Void)? = nil,
        onPlaybackStateChanged: ((PlaybackState) -> Void)? = nil,
        onPlaybackProgressChanged: ((YoutubePlaybackProgress) -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.isPlaying = isPlaying
        self.playbackFocusToken = playbackFocusToken
        self.shouldLoopPlayback = shouldLoopPlayback
        self.allowsMutedAutoplayFallback = allowsMutedAutoplayFallback
        self.respectsUserInteraction = respectsUserInteraction
        self.showsMutedFallbackControl = showsMutedFallbackControl
        self.onPlaybackEnded = onPlaybackEnded
        self.onPlaybackStateChanged = onPlaybackStateChanged
        self.onPlaybackProgressChanged = onPlaybackProgressChanged
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: Coordinator.playbackEventMessageName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.isUserInteractionEnabled = true
        webView.allowsLinkPreview = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.attach(webView: webView)

        context.coordinator.openExternalURL = { targetURL in
            openURL(targetURL)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.attach(webView: webView)
        context.coordinator.openExternalURL = { targetURL in
            openURL(targetURL)
        }
        context.coordinator.onPlaybackEnded = onPlaybackEnded
        context.coordinator.onPlaybackStateChanged = onPlaybackStateChanged
        context.coordinator.onPlaybackProgressChanged = onPlaybackProgressChanged

        guard
            let videoURL,
            let videoID = extractVideoID(from: videoURL)
        else {
            context.coordinator.redirectURL = nil
            return
        }

        context.coordinator.redirectURL = makeWatchURL(videoID: videoID) ?? videoURL

        let targetRange = YoutubePlaybackRange(startSeconds: startSeconds, endSeconds: endSeconds)
        let targetStart = targetRange.startSeconds
        let targetEnd = targetRange.endSeconds
        let mutedFallbackDelayMS = Int(YoutubePlayerAutoplayPolicy.default.mutedFallbackDelay * 1000)
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.lastSyncedStart = targetStart
            context.coordinator.lastSyncedEnd = targetEnd
            context.coordinator.lastSyncedIsPlaying = isPlaying
            context.coordinator.lastSyncedShouldLoopPlayback = shouldLoopPlayback
            context.coordinator.lastSyncedAllowsMutedAutoplayFallback = allowsMutedAutoplayFallback
            context.coordinator.lastSyncedRespectsUserInteraction = respectsUserInteraction
            context.coordinator.lastSyncedShowsMutedFallbackControl = showsMutedFallbackControl
            context.coordinator.lastSyncedPlaybackFocusToken = playbackFocusToken
            context.coordinator.hasDispatchedEnded = false
            webView.loadHTMLString(
                makePlayerHTML(
                    videoID: videoID,
                    startSeconds: targetStart,
                    endSeconds: targetEnd,
                    shouldAutoplay: isPlaying,
                    shouldLoopPlayback: shouldLoopPlayback,
                    allowsMutedAutoplayFallback: allowsMutedAutoplayFallback,
                    respectsUserInteraction: respectsUserInteraction,
                    showsMutedFallbackControl: showsMutedFallbackControl,
                    mutedFallbackDelayMS: mutedFallbackDelayMS
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
        let isSameLoopState = context.coordinator.lastSyncedShouldLoopPlayback == shouldLoopPlayback
        let isPlayStateChanged = !isSamePlayState
        let isLoopStateChanged = !isSameLoopState
        let isSameMutedFallbackState =
            context.coordinator.lastSyncedAllowsMutedAutoplayFallback == allowsMutedAutoplayFallback
        let isMutedFallbackStateChanged = !isSameMutedFallbackState
        let isSameUserInteractionState =
            context.coordinator.lastSyncedRespectsUserInteraction == respectsUserInteraction
        let isUserInteractionStateChanged = !isSameUserInteractionState
        let isSameMutedFallbackControlState =
            context.coordinator.lastSyncedShowsMutedFallbackControl == showsMutedFallbackControl
        let isMutedFallbackControlStateChanged = !isSameMutedFallbackControlState
        let isSamePlaybackFocusToken =
            context.coordinator.lastSyncedPlaybackFocusToken == playbackFocusToken
        let isPlaybackFocusTokenChanged = !isSamePlaybackFocusToken

        guard
            isRangeChanged
                || isPlayStateChanged
                || isLoopStateChanged
                || isMutedFallbackStateChanged
                || isUserInteractionStateChanged
                || isMutedFallbackControlStateChanged
                || isPlaybackFocusTokenChanged
        else {
            return
        }

        if (isPlayStateChanged || isPlaybackFocusTokenChanged) && isPlaying {
            context.coordinator.hasDispatchedEnded = false
        }

        if isRangeChanged {
            context.coordinator.lastSyncedStart = targetStart
            context.coordinator.lastSyncedEnd = targetEnd
        }
        if isPlayStateChanged {
            context.coordinator.lastSyncedIsPlaying = isPlaying
        }
        if isLoopStateChanged {
            context.coordinator.lastSyncedShouldLoopPlayback = shouldLoopPlayback
        }
        if isMutedFallbackStateChanged {
            context.coordinator.lastSyncedAllowsMutedAutoplayFallback = allowsMutedAutoplayFallback
        }
        if isUserInteractionStateChanged {
            context.coordinator.lastSyncedRespectsUserInteraction = respectsUserInteraction
        }
        if isMutedFallbackControlStateChanged {
            context.coordinator.lastSyncedShowsMutedFallbackControl = showsMutedFallbackControl
        }
        if isPlaybackFocusTokenChanged {
            context.coordinator.lastSyncedPlaybackFocusToken = playbackFocusToken
        }

        let targetStartJS = jsNumber(targetStart)
        let targetEndJS = jsNumber(targetEnd)
        let shouldAutoplayJS = isPlaying ? "true" : "false"
        let shouldLoopPlaybackJS = shouldLoopPlayback ? "true" : "false"
        let allowsMutedAutoplayFallbackJS = allowsMutedAutoplayFallback ? "true" : "false"
        let respectsUserInteractionJS = respectsUserInteraction ? "true" : "false"
        let showsMutedFallbackControlJS = showsMutedFallbackControl ? "true" : "false"
        let shouldResetControlModeJS = (isRangeChanged || (isPlayStateChanged && isPlaying)) ? "true" : "false"

        webView.evaluateJavaScript(
            """
            if (window.kpUpdateConfig) {
                window.kpUpdateConfig({
                    startSeconds: \(targetStartJS),
                    endSeconds: \(targetEndJS),
                    shouldAutoplay: \(shouldAutoplayJS),
                    shouldLoopPlayback: \(shouldLoopPlaybackJS),
                    allowsMutedAutoplayFallback: \(allowsMutedAutoplayFallbackJS),
                    respectsUserInteraction: \(respectsUserInteractionJS),
                    showsMutedFallbackControl: \(showsMutedFallbackControlJS),
                    resetControlMode: \(shouldResetControlModeJS)
                });
            } else {
                window.kpDesiredStart = \(targetStartJS);
                window.kpDesiredEnd = \(targetEndJS);
                window.kpShouldAutoplay = \(shouldAutoplayJS);
                window.kpShouldLoopPlayback = \(shouldLoopPlaybackJS);
            }
            """,
            completionHandler: nil
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        static let playbackEventMessageName = "kpPlaybackEvent"

        weak var webView: WKWebView?
        var loadedVideoID: String?
        var lastSyncedStart: Double?
        var lastSyncedEnd: Double?
        var lastSyncedIsPlaying: Bool?
        var lastSyncedShouldLoopPlayback: Bool?
        var lastSyncedAllowsMutedAutoplayFallback: Bool?
        var lastSyncedRespectsUserInteraction: Bool?
        var lastSyncedShowsMutedFallbackControl: Bool?
        var lastSyncedPlaybackFocusToken: Int?
        var redirectURL: URL?
        var openExternalURL: ((URL) -> Void)?
        var onPlaybackEnded: (() -> Void)?
        var onPlaybackStateChanged: ((PlaybackState) -> Void)?
        var onPlaybackProgressChanged: ((YoutubePlaybackProgress) -> Void)?
        var hasDispatchedEnded = false
        private var lowPowerModeObserver: NSObjectProtocol?
        private var didBecomeActiveObserver: NSObjectProtocol?
        private var willEnterForegroundObserver: NSObjectProtocol?
        private var lastKnownLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        private var lastPlaybackRecoveryKickAt: TimeInterval = 0
        private weak var tapGestureRecognizer: UITapGestureRecognizer?
        private weak var panGestureRecognizer: UIPanGestureRecognizer?

        override init() {
            super.init()
            lowPowerModeObserver = NotificationCenter.default.addObserver(
                forName: .NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleLowPowerModeChanged()
            }
            didBecomeActiveObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationDidBecomeActive()
            }
            willEnterForegroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleApplicationDidBecomeActive()
            }
        }

        deinit {
            if let lowPowerModeObserver {
                NotificationCenter.default.removeObserver(lowPowerModeObserver)
            }
            if let didBecomeActiveObserver {
                NotificationCenter.default.removeObserver(didBecomeActiveObserver)
            }
            if let willEnterForegroundObserver {
                NotificationCenter.default.removeObserver(willEnterForegroundObserver)
            }
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            installUserInteractionRecognizersIfNeeded(on: webView)
        }

        private func installUserInteractionRecognizersIfNeeded(on webView: WKWebView) {
            if tapGestureRecognizer?.view !== webView {
                if let tapGestureRecognizer {
                    tapGestureRecognizer.view?.removeGestureRecognizer(tapGestureRecognizer)
                }
                let recognizer = UITapGestureRecognizer(
                    target: self,
                    action: #selector(handleUserInteractionGesture)
                )
                recognizer.cancelsTouchesInView = false
                recognizer.delaysTouchesBegan = false
                recognizer.delaysTouchesEnded = false
                recognizer.delegate = self
                webView.addGestureRecognizer(recognizer)
                tapGestureRecognizer = recognizer
            }

            if panGestureRecognizer?.view !== webView {
                if let panGestureRecognizer {
                    panGestureRecognizer.view?.removeGestureRecognizer(panGestureRecognizer)
                }
                let recognizer = UIPanGestureRecognizer(
                    target: self,
                    action: #selector(handleUserInteractionGesture)
                )
                recognizer.cancelsTouchesInView = false
                recognizer.delaysTouchesBegan = false
                recognizer.delaysTouchesEnded = false
                recognizer.delegate = self
                webView.addGestureRecognizer(recognizer)
                panGestureRecognizer = recognizer
            }
        }

        @objc private func handleUserInteractionGesture(_ recognizer: UIGestureRecognizer) {
            switch recognizer.state {
            case .began, .ended:
                registerUserInteraction()
            default:
                break
            }
        }

        private func registerUserInteraction() {
            webView?.evaluateJavaScript(
                """
                if (window.kpRegisterUserInteraction) {
                    window.kpRegisterUserInteraction('native');
                }
                """,
                completionHandler: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard shouldOpenExternally(navigationAction) else {
                decisionHandler(.allow)
                return
            }

            openExternalURL(for: navigationAction.request.url)
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startPlaybackHeartbeat(minimumInterval: 0)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            openExternalURL(for: navigationAction.request.url)
            return nil
        }

        private func shouldOpenExternally(_ navigationAction: WKNavigationAction) -> Bool {
            let isUserNavigation =
                navigationAction.navigationType == .linkActivated
                || navigationAction.navigationType == .formSubmitted
                || navigationAction.navigationType == .formResubmitted

            if isUserNavigation {
                return true
            }

            guard navigationAction.targetFrame == nil else { return false }
            guard let url = navigationAction.request.url else { return false }
            return isHTTPURL(url)
        }

        private func openExternalURL(for targetURL: URL?) {
            if let targetURL, isHTTPURL(targetURL) {
                openExternalURL?(targetURL)
                return
            }

            openRedirectURL()
        }

        private func openRedirectURL() {
            guard let redirectURL else { return }
            openExternalURL?(redirectURL)
        }

        private func isHTTPURL(_ url: URL) -> Bool {
            let scheme = url.scheme?.lowercased()
            return scheme == "http" || scheme == "https"
        }

        private func handleLowPowerModeChanged() {
            let isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            guard isLowPowerModeEnabled != lastKnownLowPowerMode else { return }
            lastKnownLowPowerMode = isLowPowerModeEnabled
            startPlaybackHeartbeat(minimumInterval: 0)
        }

        private func handleApplicationDidBecomeActive() {
            startPlaybackHeartbeat(minimumInterval: 0)
        }

        func startPlaybackHeartbeat(minimumInterval: TimeInterval = 0.8) {
            guard let webView else { return }
            guard lastSyncedIsPlaying == true else { return }

            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastPlaybackRecoveryKickAt >= minimumInterval else { return }
            lastPlaybackRecoveryKickAt = now

            webView.evaluateJavaScript(
                """
                if (window.kpNativeResume) {
                    window.kpNativeResume();
                }
                """,
                completionHandler: nil
            )
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == Self.playbackEventMessageName else { return }
            if let event = message.body as? String {
                handlePlaybackEvent(event)
                return
            }

            guard let eventBody = message.body as? [String: Any] else { return }
            guard let type = eventBody["type"] as? String else { return }

            switch type {
            case "state":
                if let state = eventBody["state"] as? String {
                    handlePlaybackEvent("state:\(state)")
                }
            case "ended":
                handlePlaybackEvent("ended")
            case "progress":
                handleProgressEvent(eventBody)
            default:
                break
            }
        }

        private func handlePlaybackEvent(_ event: String) {
            if event == "ended" {
                guard !hasDispatchedEnded else { return }
                hasDispatchedEnded = true
                DispatchQueue.main.async {
                    self.onPlaybackStateChanged?(.ended)
                    self.onPlaybackEnded?()
                }
                return
            }

            if let playbackState = playbackState(from: event) {
                DispatchQueue.main.async {
                    self.onPlaybackStateChanged?(playbackState)
                }
            }
        }

        private func handleProgressEvent(_ eventBody: [String: Any]) {
            guard
                let currentSeconds = doubleValue(for: "currentSeconds", in: eventBody),
                let startSeconds = doubleValue(for: "startSeconds", in: eventBody),
                let endSeconds = doubleValue(for: "endSeconds", in: eventBody),
                let isInsideRange = boolValue(for: "isInsideRange", in: eventBody)
            else {
                return
            }

            let progress = YoutubePlaybackProgress(
                currentSeconds: currentSeconds,
                startSeconds: startSeconds,
                endSeconds: endSeconds,
                isInsideRange: isInsideRange
            )
            DispatchQueue.main.async {
                self.onPlaybackProgressChanged?(progress)
            }
        }

        private func doubleValue(for key: String, in eventBody: [String: Any]) -> Double? {
            if let value = eventBody[key] as? Double {
                return value
            }
            if let value = eventBody[key] as? NSNumber {
                return value.doubleValue
            }
            return nil
        }

        private func boolValue(for key: String, in eventBody: [String: Any]) -> Bool? {
            if let value = eventBody[key] as? Bool {
                return value
            }
            if let value = eventBody[key] as? NSNumber {
                return value.boolValue
            }
            return nil
        }

        private func playbackState(from event: String) -> PlaybackState? {
            guard event.hasPrefix("state:") else { return nil }
            let raw = String(event.dropFirst("state:".count))
            return PlaybackState(rawValue: raw)
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
        shouldAutoplay: Bool,
        shouldLoopPlayback: Bool,
        allowsMutedAutoplayFallback: Bool,
        respectsUserInteraction: Bool,
        showsMutedFallbackControl: Bool,
        mutedFallbackDelayMS: Int
    ) -> String {
        let safeVideoID = escapeForJavaScript(videoID)
        let safeReferer = escapeForJavaScript(appRefererURLString ?? "")
        let initialStart = max(Int(startSeconds.rounded(.down)), 0)
        let initialStartJS = jsNumber(startSeconds)
        let initialEndJS = jsNumber(endSeconds)
        let initialShouldAutoplayJS = shouldAutoplay ? "true" : "false"
        let shouldLoopPlaybackJS = shouldLoopPlayback ? "true" : "false"
        let allowsMutedAutoplayFallbackJS = allowsMutedAutoplayFallback ? "true" : "false"
        let respectsUserInteractionJS = respectsUserInteraction ? "true" : "false"
        let showsMutedFallbackControlJS = showsMutedFallbackControl ? "true" : "false"
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
                #kp-muted-fallback {
                    position: absolute;
                    left: 10px;
                    right: 10px;
                    bottom: 10px;
                    display: none;
                    align-items: center;
                    gap: 8px;
                    padding: 8px 10px;
                    border: 1px solid rgba(220, 255, 82, 0.75);
                    border-radius: 999px;
                    background: rgba(0, 0, 0, 0.72);
                    color: #ffffff;
                    font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
                    font-size: 11px;
                    line-height: 1.25;
                    z-index: 10;
                    pointer-events: auto;
                    -webkit-backdrop-filter: blur(8px);
                    backdrop-filter: blur(8px);
                }
                #kp-muted-fallback button {
                    flex: 0 0 auto;
                    border: 0;
                    border-radius: 999px;
                    padding: 6px 9px;
                    background: #dcff52;
                    color: #000000;
                    font: inherit;
                    font-weight: 700;
                }
                #kp-muted-fallback-message {
                    min-width: 0;
                    overflow: hidden;
                    text-overflow: ellipsis;
                    white-space: nowrap;
                }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <div id="kp-muted-fallback">
                <button id="kp-unmute-button" type="button">소리 켜기</button>
                <div id="kp-muted-fallback-message">
                    iOS/YouTube 정책으로 무음 자동재생 중이에요.
                </div>
            </div>
            <script>
                window.kpDesiredStart = \(initialStartJS);
                window.kpDesiredEnd = \(initialEndJS);
                window.kpShouldAutoplay = \(initialShouldAutoplayJS);
                window.kpShouldLoopPlayback = \(shouldLoopPlaybackJS);
                window.kpAllowsMutedAutoplayFallback = \(allowsMutedAutoplayFallbackJS);
                window.kpRespectsUserInteraction = \(respectsUserInteractionJS);
                window.kpShowsMutedFallbackControl = \(showsMutedFallbackControlJS);
                window.kpMutedFallbackDelayMs = \(mutedFallbackDelayMS);
                window.kpHasDispatchedEnded = false;
                window.kpPlayer = null;
                window.kpPlayerReady = false;
                window.kpHeartbeatTimer = null;
                window.kpHeartbeatIntervalMs = 250;
                window.kpControlMode = 'app';
                window.kpUserInteracted = false;
                window.kpMutedFallbackActive = false;
                window.kpHasUsedMutedFallback = false;
                window.kpHasStartedPlayback = false;
                window.kpUnmutedAutoplayAttemptAt = 0;
                window.kpAppIssuedPause = false;
                window.kpStallStartedAt = 0;
                window.kpLastPlaybackState = -1;

                window.kpDispatchPlaybackEnded = function() {
                    if (window.kpHasDispatchedEnded) {
                        return;
                    }
                    window.kpHasDispatchedEnded = true;
                    window.kpPostMessage({ type: 'ended' });
                };

                window.kpNotifyPlaybackState = function(stateLabel) {
                    window.kpPostMessage({ type: 'state', state: stateLabel });
                };

                window.kpPostMessage = function(payload) {
                    if (
                        window.webkit
                        && window.webkit.messageHandlers
                        && window.webkit.messageHandlers.\(Coordinator.playbackEventMessageName)
                    ) {
                        window.webkit.messageHandlers.\(Coordinator.playbackEventMessageName).postMessage(payload);
                    }
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

                function kpCurrentSeconds(fallback) {
                    var current = Number(
                        window.kpPlayer && window.kpPlayer.getCurrentTime
                            ? window.kpPlayer.getCurrentTime()
                            : fallback
                    );
                    return isNaN(current) ? fallback : current;
                }

                function kpIsInsideRange(current, targetStart, targetEnd) {
                    return current >= (targetStart - 0.08) && current < (targetEnd - 0.08);
                }

                function kpPlayerState() {
                    return Number(
                        window.kpPlayer && window.kpPlayer.getPlayerState
                            ? window.kpPlayer.getPlayerState()
                            : -1
                    );
                }

                function kpIsPlayingLikeState(state) {
                    return state === 1 || state === 3;
                }

                function kpIsMuted() {
                    return !!(
                        window.kpPlayer
                        && window.kpPlayer.isMuted
                        && window.kpPlayer.isMuted()
                    );
                }

                function kpSeekToStart(shouldResume) {
                    if (!window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }

                    var targetStart = kpNormalizedStart();
                    if (window.kpPlayer.seekTo) {
                        window.kpPlayer.seekTo(targetStart, true);
                    }
                    if (shouldResume && window.kpPlayer.playVideo) {
                        window.kpPlayer.playVideo();
                    }
                }

                function kpPostProgress() {
                    if (!window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }

                    var targetStart = kpNormalizedStart();
                    var targetEnd = kpNormalizedEnd(targetStart);
                    var current = kpCurrentSeconds(targetStart);
                    window.kpPostMessage({
                        type: 'progress',
                        currentSeconds: current,
                        startSeconds: targetStart,
                        endSeconds: targetEnd,
                        isInsideRange: kpIsInsideRange(current, targetStart, targetEnd)
                    });
                }

                function kpSetMutedFallbackVisible(isVisible, message) {
                    var container = document.getElementById('kp-muted-fallback');
                    var messageNode = document.getElementById('kp-muted-fallback-message');
                    if (!container || !messageNode) {
                        return;
                    }

                    container.style.display = isVisible && window.kpShowsMutedFallbackControl ? 'flex' : 'none';
                    if (message) {
                        messageNode.textContent = message;
                    }
                }

                function kpUpdateMutedFallbackControl() {
                    if (window.kpMutedFallbackActive && kpIsMuted()) {
                        kpSetMutedFallbackVisible(
                            true,
                            'iOS/YouTube 정책으로 무음 자동재생 중이에요.'
                        );
                        return;
                    }

                    kpSetMutedFallbackVisible(false, '');
                }

                function kpResetAppControl() {
                    window.kpControlMode = 'app';
                    window.kpUserInteracted = false;
                    window.kpMutedFallbackActive = false;
                    window.kpHasUsedMutedFallback = false;
                    window.kpUnmutedAutoplayAttemptAt = 0;
                    window.kpStallStartedAt = 0;
                    window.kpHasDispatchedEnded = false;
                    kpUpdateMutedFallbackControl();
                }

                window.kpRegisterUserInteraction = function(source) {
                    if (!window.kpRespectsUserInteraction) {
                        return;
                    }

                    window.kpUserInteracted = true;
                    window.kpControlMode = 'user';
                    window.kpStallStartedAt = 0;
                };

                function kpAttemptUnmutedPlayback(shouldCorrectRange) {
                    if (!window.kpPlayerReady || !window.kpPlayer || !window.kpShouldAutoplay) {
                        return;
                    }

                    var targetStart = kpNormalizedStart();
                    var targetEnd = kpNormalizedEnd(targetStart);
                    var current = kpCurrentSeconds(targetStart);
                    if (shouldCorrectRange || !kpIsInsideRange(current, targetStart, targetEnd)) {
                        kpSeekToStart(false);
                    }

                    if (!window.kpMutedFallbackActive && window.kpPlayer.unMute) {
                        window.kpPlayer.unMute();
                    }
                    if (window.kpUnmutedAutoplayAttemptAt <= 0) {
                        window.kpUnmutedAutoplayAttemptAt = Date.now();
                    }
                    if (window.kpPlayer.playVideo) {
                        window.kpPlayer.playVideo();
                    }
                }

                function kpApplyMutedFallback() {
                    if (
                        !window.kpAllowsMutedAutoplayFallback
                        || window.kpHasUsedMutedFallback
                        || window.kpUserInteracted
                        || !window.kpPlayerReady
                        || !window.kpPlayer
                    ) {
                        return;
                    }

                    window.kpHasUsedMutedFallback = true;
                    window.kpMutedFallbackActive = true;
                    if (window.kpPlayer.mute) {
                        window.kpPlayer.mute();
                    }
                    kpUpdateMutedFallbackControl();
                    kpSeekToStart(false);
                    if (window.kpPlayer.playVideo) {
                        window.kpPlayer.playVideo();
                    }
                }

                function kpPauseFromApp() {
                    if (!window.kpPlayerReady || !window.kpPlayer || !window.kpPlayer.pauseVideo) {
                        return;
                    }
                    window.kpAppIssuedPause = true;
                    window.kpPlayer.pauseVideo();
                    setTimeout(function() {
                        window.kpAppIssuedPause = false;
                    }, 300);
                }

                function kpCorrectRangeIfNeeded(state) {
                    var targetStart = kpNormalizedStart();
                    var targetEnd = kpNormalizedEnd(targetStart);
                    var current = kpCurrentSeconds(targetStart);
                    var isInside = kpIsInsideRange(current, targetStart, targetEnd);

                    if (!isInside && (current < targetStart - 0.16 || current >= targetEnd)) {
                        var shouldResume = window.kpControlMode === 'app' || kpIsPlayingLikeState(state);
                        kpSeekToStart(shouldResume);
                        return false;
                    }

                    if (!window.kpShouldLoopPlayback && current >= targetEnd - 0.08) {
                        kpPauseFromApp();
                        window.kpDispatchPlaybackEnded();
                        return false;
                    }

                    if (window.kpShouldLoopPlayback && current >= targetEnd - 0.08) {
                        kpSeekToStart(window.kpControlMode === 'app' || kpIsPlayingLikeState(state));
                        return false;
                    }

                    return true;
                }

                function kpHeartbeat() {
                    if (!window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }

                    kpPostProgress();
                    kpUpdateMutedFallbackControl();

                    var state = kpPlayerState();
                    if (state === 1) {
                        window.kpHasStartedPlayback = true;
                        window.kpHasDispatchedEnded = false;
                        window.kpStallStartedAt = 0;
                        if (!kpIsMuted()) {
                            window.kpMutedFallbackActive = false;
                            kpUpdateMutedFallbackControl();
                        }
                    }

                    if (!window.kpShouldAutoplay) {
                        return;
                    }

                    if (!kpCorrectRangeIfNeeded(state)) {
                        return;
                    }

                    if (window.kpControlMode === 'user') {
                        return;
                    }

                    if (state === 1) {
                        return;
                    }

                    if (state === 3) {
                        if (window.kpStallStartedAt <= 0) {
                            window.kpStallStartedAt = Date.now();
                        } else if (Date.now() - window.kpStallStartedAt > 3500) {
                            window.kpNotifyPlaybackState('stalled');
                            if (window.kpPlayer.playVideo) {
                                window.kpPlayer.playVideo();
                            }
                        }
                        return;
                    }

                    if (window.kpUnmutedAutoplayAttemptAt <= 0) {
                        kpAttemptUnmutedPlayback(false);
                        return;
                    }

                    if (
                        window.kpAllowsMutedAutoplayFallback
                        && !window.kpHasUsedMutedFallback
                        && !window.kpUserInteracted
                        && Date.now() - window.kpUnmutedAutoplayAttemptAt >= window.kpMutedFallbackDelayMs
                    ) {
                        kpApplyMutedFallback();
                        return;
                    }

                    if (state === -1 || state === 0 || state === 2 || state === 5) {
                        kpAttemptUnmutedPlayback(false);
                    }
                }

                window.kpStartHeartbeat = function() {
                    if (window.kpHeartbeatTimer) {
                        return;
                    }
                    window.kpHeartbeatTimer = setInterval(kpHeartbeat, window.kpHeartbeatIntervalMs);
                };

                window.kpStopHeartbeat = function() {
                    if (window.kpHeartbeatTimer) {
                        clearInterval(window.kpHeartbeatTimer);
                        window.kpHeartbeatTimer = null;
                    }
                };

                window.kpNativeResume = function() {
                    window.kpStartHeartbeat();
                };

                window.kpUpdateConfig = function(config) {
                    if (!config) {
                        return;
                    }

                    var wasAutoplay = window.kpShouldAutoplay;
                    window.kpDesiredStart = Number(config.startSeconds);
                    window.kpDesiredEnd = Number(config.endSeconds);
                    window.kpShouldAutoplay = !!config.shouldAutoplay;
                    window.kpShouldLoopPlayback = !!config.shouldLoopPlayback;
                    window.kpAllowsMutedAutoplayFallback = !!config.allowsMutedAutoplayFallback;
                    window.kpRespectsUserInteraction = !!config.respectsUserInteraction;
                    window.kpShowsMutedFallbackControl = !!config.showsMutedFallbackControl;

                    if (config.resetControlMode) {
                        kpResetAppControl();
                    }

                    kpUpdateMutedFallbackControl();

                    if (!window.kpShouldAutoplay) {
                        kpPauseFromApp();
                        return;
                    }

                    window.kpStartHeartbeat();
                    if (!wasAutoplay || config.resetControlMode) {
                        kpAttemptUnmutedPlayback(!!config.resetControlMode);
                    }
                };

                function kpStateLabel(state) {
                    if (state === -1) {
                        return 'unstarted';
                    }
                    if (state === 1) {
                        return 'playing';
                    }
                    if (state === 3) {
                        return 'buffering';
                    }
                    if (state === 2 || state === 5) {
                        return 'paused';
                    }
                    if (state === 0) {
                        return 'ended';
                    }
                    return null;
                }

                function kpHandleStateChange(state) {
                    var label = kpStateLabel(state);
                    if (label) {
                        window.kpNotifyPlaybackState(label);
                    }

                    window.kpLastPlaybackState = state;

                    if (state === 1) {
                        window.kpHasStartedPlayback = true;
                        window.kpHasDispatchedEnded = false;
                        window.kpStallStartedAt = 0;
                        if (!kpIsMuted()) {
                            window.kpMutedFallbackActive = false;
                            kpUpdateMutedFallbackControl();
                        }
                        return;
                    }

                    if (
                        state === 2
                        && window.kpShouldAutoplay
                        && window.kpControlMode === 'app'
                        && window.kpHasStartedPlayback
                        && !window.kpAppIssuedPause
                        && window.kpRespectsUserInteraction
                    ) {
                        window.kpRegisterUserInteraction('youtube-pause');
                        return;
                    }

                    if (state === 0 && window.kpShouldAutoplay) {
                        if (window.kpShouldLoopPlayback) {
                            kpSeekToStart(window.kpControlMode === 'app');
                            return;
                        }
                        window.kpDispatchPlaybackEnded();
                    }
                }

                function kpTryUserUnmute() {
                    window.kpRegisterUserInteraction('unmute-button');
                    if (!window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }

                    if (window.kpPlayer.unMute) {
                        window.kpPlayer.unMute();
                    }
                    if (window.kpPlayer.playVideo) {
                        window.kpPlayer.playVideo();
                    }
                    setTimeout(function() {
                        if (!kpIsMuted()) {
                            window.kpMutedFallbackActive = false;
                            kpUpdateMutedFallbackControl();
                            return;
                        }

                        kpSetMutedFallbackVisible(
                            true,
                            '브라우저 정책상 소리 자동재생이 제한됐어요. 다시 눌러 주세요.'
                        );
                    }, 350);
                }

                var unmuteButton = document.getElementById('kp-unmute-button');
                if (unmuteButton) {
                    unmuteButton.addEventListener('click', function(event) {
                        event.preventDefault();
                        event.stopPropagation();
                        kpTryUserUnmute();
                    });
                }

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
                            enablejsapi: 1,
                            mute: 0,
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
                                var iframe = window.kpPlayer.getIframe ? window.kpPlayer.getIframe() : null;
                                if (iframe) {
                                    iframe.setAttribute(
                                        'allow',
                                        'autoplay; encrypted-media; fullscreen; picture-in-picture'
                                    );
                                }
                                if (window.kpShouldAutoplay) {
                                    window.kpStartHeartbeat();
                                    kpAttemptUnmutedPlayback(true);
                                } else {
                                    if (window.kpPlayer.unMute) {
                                        window.kpPlayer.unMute();
                                    }
                                    window.kpPlayer.seekTo(window.kpDesiredStart, true);
                                    kpPauseFromApp();
                                }
                            },
                            onStateChange: function(event) {
                                kpHandleStateChange(Number(event.data));
                            }
                        }
                    });
                };

                document.addEventListener('visibilitychange', function() {
                    if (document.visibilityState === 'visible') {
                        window.kpNativeResume();
                    }
                });

                window.addEventListener('pageshow', function() {
                    window.kpNativeResume();
                });

                window.addEventListener('focus', function() {
                    window.kpNativeResume();
                });

                window.addEventListener('beforeunload', function() {
                    window.kpStopHeartbeat();
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
