import SwiftUI
import UIKit
import WebKit

struct YoutubePlayerView: UIViewRepresentable {
    enum PlaybackState: String, Equatable {
        case playing
        case paused
        case buffering
        case ended
    }

    @Environment(\.openURL) private var openURL

    let videoURL: URL?
    let startSeconds: Double
    let endSeconds: Double
    let isPlaying: Bool
    let playbackFocusToken: Int
    let shouldLoopPlayback: Bool
    let onPlaybackEnded: (() -> Void)?
    let onPlaybackStateChanged: ((PlaybackState) -> Void)?

    init(
        videoURL: URL?,
        startSeconds: Double,
        endSeconds: Double,
        isPlaying: Bool = true,
        playbackFocusToken: Int = 0,
        shouldLoopPlayback: Bool = true,
        onPlaybackEnded: (() -> Void)? = nil,
        onPlaybackStateChanged: ((PlaybackState) -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.isPlaying = isPlaying
        self.playbackFocusToken = playbackFocusToken
        self.shouldLoopPlayback = shouldLoopPlayback
        self.onPlaybackEnded = onPlaybackEnded
        self.onPlaybackStateChanged = onPlaybackStateChanged
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
        let preferMutedAutoplay = false
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.lastSyncedStart = targetStart
            context.coordinator.lastSyncedEnd = targetEnd
            context.coordinator.lastSyncedIsPlaying = isPlaying
            context.coordinator.lastSyncedShouldLoopPlayback = shouldLoopPlayback
            context.coordinator.lastSyncedPreferMutedAutoplay = preferMutedAutoplay
            context.coordinator.lastSyncedPlaybackFocusToken = playbackFocusToken
            context.coordinator.hasDispatchedEnded = false
            webView.loadHTMLString(
                makePlayerHTML(
                    videoID: videoID,
                    startSeconds: targetStart,
                    endSeconds: targetEnd,
                    shouldAutoplay: isPlaying,
                    shouldLoopPlayback: shouldLoopPlayback,
                    preferMutedAutoplay: preferMutedAutoplay
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
        let isSameMutedAutoplayPreference =
            context.coordinator.lastSyncedPreferMutedAutoplay == preferMutedAutoplay
        let isMutedAutoplayPreferenceChanged = !isSameMutedAutoplayPreference
        let isSamePlaybackFocusToken =
            context.coordinator.lastSyncedPlaybackFocusToken == playbackFocusToken
        let isPlaybackFocusTokenChanged = !isSamePlaybackFocusToken

        guard
            isRangeChanged
                || isPlayStateChanged
                || isLoopStateChanged
                || isMutedAutoplayPreferenceChanged
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
        if isPlayStateChanged || isMutedAutoplayPreferenceChanged {
            context.coordinator.lastSyncedPreferMutedAutoplay = preferMutedAutoplay
        }
        if isPlaybackFocusTokenChanged {
            context.coordinator.lastSyncedPlaybackFocusToken = playbackFocusToken
        }

        let targetStartJS = jsNumber(targetStart)
        let targetEndJS = jsNumber(targetEnd)
        let shouldAutoplayJS = isPlaying ? "true" : "false"
        let shouldLoopPlaybackJS = shouldLoopPlayback ? "true" : "false"
        let preferMutedAutoplayJS = preferMutedAutoplay ? "true" : "false"
        // Keep playback position when only play/pause state changes.
        // Force seek is needed when the target range changes or focus returns to this player.
        let shouldForceSeekJS = (isRangeChanged || (isPlaying && isPlaybackFocusTokenChanged)) ? "true" : "false"
        let playbackControlJS = isPlaying
            ? """
            window.kpHasDispatchedEnded = false;
            if (window.kpSetPreferMutedAutoplay) {
                window.kpSetPreferMutedAutoplay(\(preferMutedAutoplayJS));
            } else {
                window.kpPreferMutedAutoplay = \(preferMutedAutoplayJS);
                window.kpAutoplayMutedFallbackActive = false;
                window.kpAutoplayAudioRestoreAttempted = false;
            }
            if (window.kpApplyDesiredRange) {
                window.kpApplyDesiredRange(\(shouldForceSeekJS));
                if (window.kpStartRangeLoop) {
                    window.kpStartRangeLoop();
                }
                if (window.kpResumeAutoplayIfNeeded) {
                    window.kpResumeAutoplayIfNeeded(\(shouldForceSeekJS));
                }
                if (window.kpScheduleAutoplayRetry) {
                    window.kpScheduleAutoplayRetry(\(shouldForceSeekJS));
                }
            } else {
                if (\(shouldForceSeekJS)) {
                    window.kpPlayer.seekTo(window.kpDesiredStart, true);
                }
                window.kpPlayer.playVideo();
            }
            if (window.kpStartPlaybackWatchdog) {
                window.kpStartPlaybackWatchdog();
            }
            """
            : """
            if (window.kpStopAutoplayRetry) {
                window.kpStopAutoplayRetry();
            }
            if (window.kpStopPlaybackWatchdog) {
                window.kpStopPlaybackWatchdog();
            }
            if (window.kpStopRangeLoop) {
                window.kpStopRangeLoop();
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
            window.kpShouldLoopPlayback = \(shouldLoopPlaybackJS);
            window.kpPreferMutedAutoplay = \(preferMutedAutoplayJS);
            if (window.kpSetPreferMutedAutoplay) {
                window.kpSetPreferMutedAutoplay(window.kpPreferMutedAutoplay);
            }
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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        static let playbackEventMessageName = "kpPlaybackEvent"

        weak var webView: WKWebView?
        var loadedVideoID: String?
        var lastSyncedStart: Double?
        var lastSyncedEnd: Double?
        var lastSyncedIsPlaying: Bool?
        var lastSyncedShouldLoopPlayback: Bool?
        var lastSyncedPreferMutedAutoplay: Bool?
        var lastSyncedPlaybackFocusToken: Int?
        var redirectURL: URL?
        var openExternalURL: ((URL) -> Void)?
        var onPlaybackEnded: (() -> Void)?
        var onPlaybackStateChanged: ((PlaybackState) -> Void)?
        var hasDispatchedEnded = false
        private var lowPowerModeObserver: NSObjectProtocol?
        private var didBecomeActiveObserver: NSObjectProtocol?
        private var willEnterForegroundObserver: NSObjectProtocol?
        private var lastKnownLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        private var lastPlaybackRecoveryKickAt: TimeInterval = 0

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
            applyAutoplayPolicyForCurrentPowerMode(forceSeek: true)
            kickPlaybackRecoveryIfNeeded(forceSeek: false, minimumInterval: 0)
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
            applyAutoplayPolicyForCurrentPowerMode(forceSeek: false)
            kickPlaybackRecoveryIfNeeded(forceSeek: false, minimumInterval: 0)
        }

        private func handleApplicationDidBecomeActive() {
            applyAutoplayPolicyForCurrentPowerMode(forceSeek: true)
            kickPlaybackRecoveryIfNeeded(forceSeek: true, minimumInterval: 0)
        }

        func kickPlaybackRecoveryIfNeeded(forceSeek: Bool, minimumInterval: TimeInterval = 0.8) {
            guard let webView else { return }
            guard lastSyncedIsPlaying == true else { return }

            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastPlaybackRecoveryKickAt >= minimumInterval else { return }
            lastPlaybackRecoveryKickAt = now

            let shouldForceSeekJS = forceSeek ? "true" : "false"
            webView.evaluateJavaScript(
                """
                if (!window.kpShouldAutoplay) {
                    window.kpShouldAutoplay = true;
                }
                if (window.kpSetPreferMutedAutoplay) {
                    window.kpSetPreferMutedAutoplay(window.kpPreferMutedAutoplay);
                }
                if (window.kpStartRangeLoop) {
                    window.kpStartRangeLoop();
                }
                if (window.kpStartPlaybackWatchdog) {
                    window.kpStartPlaybackWatchdog();
                }
                if (window.kpApplyDesiredRange) {
                    window.kpApplyDesiredRange(\(shouldForceSeekJS));
                }
                if (window.kpResumeAutoplayIfNeeded) {
                    window.kpResumeAutoplayIfNeeded(\(shouldForceSeekJS));
                }
                if (window.kpScheduleAutoplayRetry) {
                    window.kpScheduleAutoplayRetry(false);
                }
                """,
                completionHandler: nil
            )
        }

        private func applyAutoplayPolicyForCurrentPowerMode(forceSeek: Bool) {
            guard let webView, let isPlaying = lastSyncedIsPlaying else { return }

            let preferMutedAutoplay = false
            lastSyncedPreferMutedAutoplay = preferMutedAutoplay

            let shouldAutoplayJS = isPlaying ? "true" : "false"
            let preferMutedAutoplayJS = preferMutedAutoplay ? "true" : "false"
            let shouldForceSeekJS = forceSeek ? "true" : "false"

            webView.evaluateJavaScript(
                """
                window.kpShouldAutoplay = \(shouldAutoplayJS);
                window.kpPreferMutedAutoplay = \(preferMutedAutoplayJS);
                if (window.kpSetPreferMutedAutoplay) {
                    window.kpSetPreferMutedAutoplay(\(preferMutedAutoplayJS));
                }
                if (\(shouldAutoplayJS) && window.kpPlayerReady && window.kpPlayer) {
                    window.kpHasDispatchedEnded = false;
                    if (window.kpApplyDesiredRange) {
                        window.kpApplyDesiredRange(\(shouldForceSeekJS));
                    } else {
                        if (\(shouldForceSeekJS)) {
                            window.kpPlayer.seekTo(window.kpDesiredStart, true);
                        }
                        window.kpPlayer.playVideo();
                    }
                    if (window.kpStartRangeLoop) {
                        window.kpStartRangeLoop();
                    }
                    if (window.kpResumeAutoplayIfNeeded) {
                        window.kpResumeAutoplayIfNeeded(\(shouldForceSeekJS));
                    }
                    if (window.kpScheduleAutoplayRetry) {
                        window.kpScheduleAutoplayRetry(\(shouldForceSeekJS));
                    }
                    if (window.kpStartPlaybackWatchdog) {
                        window.kpStartPlaybackWatchdog();
                    }
                } else {
                    if (window.kpStopRangeLoop) {
                        window.kpStopRangeLoop();
                    }
                    if (window.kpStopPlaybackWatchdog) {
                        window.kpStopPlaybackWatchdog();
                    }
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
            guard let event = message.body as? String else { return }

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
        preferMutedAutoplay: Bool
    ) -> String {
        let safeVideoID = escapeForJavaScript(videoID)
        let safeReferer = escapeForJavaScript(appRefererURLString ?? "")
        let initialStart = max(Int(startSeconds.rounded(.down)), 0)
        let initialStartJS = jsNumber(startSeconds)
        let initialEndJS = jsNumber(endSeconds)
        let initialShouldAutoplayJS = shouldAutoplay ? "true" : "false"
        let shouldLoopPlaybackJS = shouldLoopPlayback ? "true" : "false"
        let preferMutedAutoplayJS = preferMutedAutoplay ? "true" : "false"
        let autoplayFlag = shouldAutoplay ? 1 : 0
        let muteFlag = 0

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
                window.kpShouldLoopPlayback = \(shouldLoopPlaybackJS);
                window.kpHasDispatchedEnded = false;
                window.kpPlayer = null;
                window.kpPlayerReady = false;
                window.kpLoopTimer = null;
                window.kpPlaybackWatchdogTimer = null;
                window.kpAutoplayRetryTimer = null;
                window.kpAutoplayRetryCount = 0;
                window.kpAutoplayBaseRetryDelayMs = 220;
                window.kpAutoplayRetryBackoffStepMs = 120;
                window.kpAutoplayRetryMaxDelayMs = 1600;
                window.kpAutoplayMuteFallbackAfterCount = 0;
                window.kpPreferMutedAutoplay = false;
                window.kpAutoplayMutedFallbackActive = false;
                window.kpAutoplayAudioRestoreAttempted = false;

                window.kpStopAutoplayRetry = function() {
                    if (window.kpAutoplayRetryTimer) {
                        clearTimeout(window.kpAutoplayRetryTimer);
                        window.kpAutoplayRetryTimer = null;
                    }
                    window.kpAutoplayRetryCount = 0;
                };

                window.kpNextAutoplayRetryDelayMs = function() {
                    var baseDelay = Number(window.kpAutoplayBaseRetryDelayMs || 220);
                    var backoffStep = Number(window.kpAutoplayRetryBackoffStepMs || 120);
                    var maxDelay = Number(window.kpAutoplayRetryMaxDelayMs || 1600);
                    if (isNaN(baseDelay) || baseDelay < 120) {
                        baseDelay = 220;
                    }
                    if (isNaN(backoffStep) || backoffStep < 0) {
                        backoffStep = 120;
                    }
                    if (isNaN(maxDelay) || maxDelay < baseDelay) {
                        maxDelay = 1600;
                    }

                    var retryCount = Number(window.kpAutoplayRetryCount || 0);
                    if (isNaN(retryCount) || retryCount < 0) {
                        retryCount = 0;
                    }

                    var delay = baseDelay + (retryCount * backoffStep);
                    if (delay > maxDelay) {
                        delay = maxDelay;
                    }
                    return delay;
                };

                window.kpResumeAutoplayIfNeeded = function(forceSeek) {
                    if (!window.kpShouldAutoplay || !window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }

                    var state = Number(window.kpPlayer.getPlayerState ? window.kpPlayer.getPlayerState() : -1);
                    if (state === 1 || state === 3) {
                        return;
                    }
                    window.kpScheduleAutoplayRetry(forceSeek);
                };

                window.kpSetPreferMutedAutoplay = function(shouldPreferMutedAutoplay) {
                    window.kpPreferMutedAutoplay = false;
                    window.kpAutoplayMutedFallbackActive = false;
                    if (window.kpPlayer && window.kpPlayer.unMute) {
                        window.kpPlayer.unMute();
                    }
                    window.kpAutoplayAudioRestoreAttempted = false;
                };

                window.kpDispatchPlaybackEnded = function() {
                    if (window.kpHasDispatchedEnded) {
                        return;
                    }
                    window.kpHasDispatchedEnded = true;
                    if (
                        window.webkit
                        && window.webkit.messageHandlers
                        && window.webkit.messageHandlers.\(Coordinator.playbackEventMessageName)
                    ) {
                        window.webkit.messageHandlers.\(Coordinator.playbackEventMessageName).postMessage('ended');
                    }
                };

                window.kpNotifyPlaybackState = function(stateLabel) {
                    if (
                        window.webkit
                        && window.webkit.messageHandlers
                        && window.webkit.messageHandlers.\(Coordinator.playbackEventMessageName)
                    ) {
                        window.webkit.messageHandlers.\(Coordinator.playbackEventMessageName).postMessage(
                            'state:' + stateLabel
                        );
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

                    if (window.kpPlayer.unMute) {
                        window.kpPlayer.unMute();
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

                    var retryDelay = window.kpNextAutoplayRetryDelayMs();
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

                        window.kpAutoplayRetryCount = Math.min(window.kpAutoplayRetryCount + 1, 20);
                        window.kpScheduleAutoplayRetry(false);
                    }, retryDelay);
                };

                window.kpStopRangeLoop = function() {
                    if (window.kpLoopTimer) {
                        clearInterval(window.kpLoopTimer);
                        window.kpLoopTimer = null;
                    }
                };

                window.kpStartRangeLoop = function() {
                    window.kpStopRangeLoop();

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
                            
                            // 종료 판정을 너무 일찍 하지 않도록 여유를 최소화한다.
                            if (
                                !window.kpShouldLoopPlayback
                                && !isNaN(current)
                                && current >= (targetEnd - 0.08)
                            ) {
                                if (window.kpPlayer.pauseVideo) {
                                    window.kpPlayer.pauseVideo();
                                }
                                window.kpDispatchPlaybackEnded();
                                return;
                            }

                            if (isNaN(current) || current < targetStart || current >= targetEnd) {
                                window.kpPlayer.seekTo(targetStart, true);
                                window.kpPlayer.playVideo();
                            }
                            return;
                        }

                        if (state === 0 || state === 2 || state === 5 || state === -1) {
                            window.kpResumeAutoplayIfNeeded(false);
                        }
                    }, 200);
                };

                window.kpStopPlaybackWatchdog = function() {
                    if (window.kpPlaybackWatchdogTimer) {
                        clearInterval(window.kpPlaybackWatchdogTimer);
                        window.kpPlaybackWatchdogTimer = null;
                    }
                };

                window.kpStartPlaybackWatchdog = function() {
                    window.kpStopPlaybackWatchdog();
                    window.kpPlaybackWatchdogTimer = setInterval(function() {
                        if (!window.kpShouldAutoplay || !window.kpPlayerReady || !window.kpPlayer) {
                            return;
                        }

                        var state = Number(window.kpPlayer.getPlayerState ? window.kpPlayer.getPlayerState() : -1);
                        if (state === 1 || state === 3) {
                            var isMuted = !!(window.kpPlayer.isMuted && window.kpPlayer.isMuted());
                            if (!isMuted) {
                                window.kpAutoplayAudioRestoreAttempted = false;
                                window.kpAutoplayMutedFallbackActive = false;
                                return;
                            }

                            if (window.kpAutoplayAudioRestoreAttempted || !window.kpPlayer.unMute) {
                                return;
                            }

                            window.kpAutoplayAudioRestoreAttempted = true;
                            window.kpPlayer.unMute();
                            setTimeout(function() {
                                if (!window.kpShouldAutoplay || !window.kpPlayer) {
                                    return;
                                }

                                var stateAfterUnmute = Number(
                                    window.kpPlayer.getPlayerState
                                        ? window.kpPlayer.getPlayerState()
                                        : -1
                                );
                                var isMutedAfterUnmute = !!(
                                    window.kpPlayer.isMuted
                                    && window.kpPlayer.isMuted()
                                );

                                if (
                                    (stateAfterUnmute === 1 || stateAfterUnmute === 3)
                                    && !isMutedAfterUnmute
                                ) {
                                    window.kpAutoplayMutedFallbackActive = false;
                                    window.kpAutoplayAudioRestoreAttempted = false;
                                    return;
                                }

                                window.kpAutoplayAudioRestoreAttempted = false;
                                if (
                                    stateAfterUnmute !== 1
                                    && stateAfterUnmute !== 3
                                    && window.kpPlayer.playVideo
                                ) {
                                    window.kpPlayer.playVideo();
                                }
                                if (window.kpResumeAutoplayIfNeeded) {
                                    window.kpResumeAutoplayIfNeeded(false);
                                }
                            }, 180);
                            return;
                        }

                        window.kpResumeAutoplayIfNeeded(false);
                    }, 900);
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
                            mute: \(muteFlag),
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
                                window.kpSetPreferMutedAutoplay(window.kpPreferMutedAutoplay);
                                if (window.kpShouldAutoplay) {
                                    window.kpApplyDesiredRange(true);
                                    window.kpStartRangeLoop();
                                    window.kpStartPlaybackWatchdog();
                                    window.kpResumeAutoplayIfNeeded(true);
                                } else {
                                    if (window.kpStopRangeLoop) {
                                        window.kpStopRangeLoop();
                                    }
                                    window.kpStopPlaybackWatchdog();
                                    if (window.kpPlayer.unMute) {
                                        window.kpPlayer.unMute();
                                    }
                                    window.kpPlayer.seekTo(window.kpDesiredStart, true);
                                    window.kpPlayer.pauseVideo();
                                }
                            },
                            onStateChange: function(event) {
                                var state = Number(event.data);
                                if (state === 1) {
                                    window.kpNotifyPlaybackState('playing');
                                } else if (state === 3) {
                                    window.kpNotifyPlaybackState('buffering');
                                } else if (state === 2 || state === 5) {
                                    window.kpNotifyPlaybackState('paused');
                                } else if (state === 0) {
                                    window.kpNotifyPlaybackState('ended');
                                }

                                if (!window.kpShouldAutoplay) {
                                    return;
                                }

                                if (state === 1 || state === 3) {
                                    window.kpHasDispatchedEnded = false;
                                    window.kpStopAutoplayRetry();
                                    window.kpStartPlaybackWatchdog();
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
                                                window.kpAutoplayAudioRestoreAttempted = false;
                                                return;
                                            }

                                            window.kpPlayer.unMute();

                                            var stateAfterUnmute = Number(
                                                window.kpPlayer.getPlayerState
                                                    ? window.kpPlayer.getPlayerState()
                                                    : -1
                                            );
                                            var isMutedAfterUnmute = !!(
                                                window.kpPlayer.isMuted
                                                && window.kpPlayer.isMuted()
                                            );
                                            if (
                                                (stateAfterUnmute === 1 || stateAfterUnmute === 3)
                                                && !isMutedAfterUnmute
                                            ) {
                                                window.kpAutoplayMutedFallbackActive = false;
                                                window.kpAutoplayAudioRestoreAttempted = false;
                                                return;
                                            }

                                            window.kpAutoplayAudioRestoreAttempted = false;
                                            if (window.kpPlayer.playVideo) {
                                                window.kpPlayer.playVideo();
                                            }
                                            if (window.kpResumeAutoplayIfNeeded) {
                                                window.kpResumeAutoplayIfNeeded(false);
                                            }
                                        }, 160);
                                    }
                                    return;
                                }

                                if (state === 0) {
                                    if (window.kpShouldLoopPlayback) {
                                        window.kpApplyDesiredRange(true);
                                        window.kpScheduleAutoplayRetry(true);
                                    } else {
                                        window.kpDispatchPlaybackEnded();
                                    }
                                    return;
                                }

                                if (state === 2 || state === 5 || state === -1) {
                                    window.kpResumeAutoplayIfNeeded(false);
                                }
                            }
                        }
                    });
                };

                document.addEventListener('visibilitychange', function() {
                    if (document.visibilityState === 'visible') {
                        window.kpStartRangeLoop();
                        window.kpStartPlaybackWatchdog();
                        window.kpResumeAutoplayIfNeeded(true);
                    }
                });

                window.addEventListener('pageshow', function() {
                    window.kpStartRangeLoop();
                    window.kpStartPlaybackWatchdog();
                    window.kpResumeAutoplayIfNeeded(true);
                });

                window.addEventListener('focus', function() {
                    window.kpStartRangeLoop();
                    window.kpStartPlaybackWatchdog();
                    window.kpResumeAutoplayIfNeeded(false);
                });

                window.addEventListener('beforeunload', function() {
                    if (window.kpStopRangeLoop) {
                        window.kpStopRangeLoop();
                    }
                    if (window.kpAutoplayRetryTimer) {
                        clearTimeout(window.kpAutoplayRetryTimer);
                        window.kpAutoplayRetryTimer = null;
                    }
                    if (window.kpPlaybackWatchdogTimer) {
                        clearInterval(window.kpPlaybackWatchdogTimer);
                        window.kpPlaybackWatchdogTimer = null;
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
