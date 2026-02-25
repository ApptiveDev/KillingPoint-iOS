import SwiftUI
import UIKit
import WebKit

struct AddSearchDetailView: View {
    @StateObject private var viewModel: AddSearchDetailViewModel

    init(track: SpotifySimpleTrack) {
        _viewModel = StateObject(wrappedValue: AddSearchDetailViewModel(track: track))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AddSearchDetailVideoSection(viewModel: viewModel)
                    AddSearchDetailTrackInfoSection(track: viewModel.track)
                    AddSearchDetailTrimSection(viewModel: viewModel)

                    if viewModel.videos.count > 1 {
                        AddSearchDetailVideoCandidateSection(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .navigationTitle("음악 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

private struct AddSearchDetailVideoSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("유튜브 영상")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white.opacity(0.9))

            Group {
                if viewModel.isLoading {
                    loadingView
                } else if let video = viewModel.selectedVideo {
                    VStack(alignment: .leading, spacing: AppSpacing.s) {
                        YoutubePlayerView(
                            videoURL: video.embedURL,
                            startSeconds: viewModel.startSeconds
                        )
                            .frame(height: 220)
                            .allowsHitTesting(false)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            }

                        Text(video.title)
                            .font(AppFont.paperlogy5Medium(size: 14))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("길이 \(viewModel.selectedVideoDurationText)")
                            .font(AppFont.paperlogy4Regular(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else {
                    emptyView
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: AppSpacing.s) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.primary600)

            Text("유튜브 영상 검색 중...")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func errorView(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(message)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.85))

            Button {
                Task {
                    await viewModel.retry()
                }
            } label: {
                Text("다시 검색")
                    .font(AppFont.paperlogy6SemiBold(size: 13))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppColors.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyView: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "play.rectangle")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(AppColors.primary600)

            Text("검색된 유튜브 영상이 없어요.")
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct AddSearchDetailTrackInfoSection: View {
    let track: SpotifySimpleTrack

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            AddSearchDetailAlbumArtworkView(url: track.albumImageURL)

            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(track.artist)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AddSearchDetailTrimSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("구간 자르기")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white.opacity(0.9))

            if viewModel.hasPlayableVideo {
                HStack {
                    Text("시작 \(viewModel.startTimeText)")
                    Spacer()
                    Text("끝 \(viewModel.endTimeText)")
                }
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(.white.opacity(0.72))

                AddSearchDetailWaveformTrimView(
                    startSeconds: Binding(
                        get: { viewModel.startSeconds },
                        set: { viewModel.updateStart($0) }
                    ),
                    endSeconds: Binding(
                        get: { viewModel.endSeconds },
                        set: { viewModel.updateEnd($0) }
                    ),
                    duration: viewModel.maxDuration,
                    onUpdateRange: { start, end in
                        viewModel.updateRange(start: start, end: end)
                    }
                )
                .frame(height: 138)

                HStack {
                    Text("선택 구간 길이 \(viewModel.clipDurationText)")
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)

                    Spacer()

                    Text("최대 30초")
                        .font(AppFont.paperlogy4Regular(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Text("<, > 핸들을 좌우로 드래그해서 구간을 조절하고, 음파는 가로 스크롤할 수 있어요.")
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                Text("영상을 찾지 못해 구간 자르기를 사용할 수 없어요.")
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(AppSpacing.m)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct AddSearchDetailWaveformTrimView: View {
    @Binding var startSeconds: Double
    @Binding var endSeconds: Double
    let duration: Double
    let onUpdateRange: (_ start: Double, _ end: Double) -> Void

    private let horizontalPadding: CGFloat = 18
    private let pointsPerSecond: CGFloat = 18
    private let trackHeight: CGFloat = 104
    private let overviewHeight: CGFloat = 24
    private let overviewHorizontalInset: CGFloat = 8
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3
    private let handleWidth: CGFloat = 34
    private let handleCornerRadius: CGFloat = 14

    @State private var startDragBase: Double?
    @State private var endDragBase: Double?

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = max(proxy.size.width, 1)
            let contentWidth = max(
                viewportWidth,
                CGFloat(max(duration, 1)) * pointsPerSecond + horizontalPadding * 2
            )

            VStack(spacing: AppSpacing.xs) {
                ScrollView(.horizontal, showsIndicators: false) {
                    trimTrack(contentWidth: contentWidth)
                        .frame(width: contentWidth, height: trackHeight)
                }

                overviewBar(width: viewportWidth)
            }
        }
    }

    private func trimTrack(contentWidth: CGFloat) -> some View {
        let startX = xPosition(for: startSeconds, contentWidth: contentWidth)
        let endX = xPosition(for: endSeconds, contentWidth: contentWidth)
        let selectedWidth = max(endX - startX, 1)
        let trailingWidth = max(contentWidth - endX, 0)

        return ZStack(alignment: .leading) {
            waveformBars(contentWidth: contentWidth)
                .zIndex(0)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: max(startX, 0))

                Rectangle()
                    .fill(AppColors.primary600.opacity(0.25))
                    .frame(width: selectedWidth)

                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: trailingWidth)
            }
            .allowsHitTesting(false)
            .zIndex(1)

            trimHandle(direction: .left)
                .position(x: startX, y: trackHeight / 2)
                .highPriorityGesture(startHandleDragGesture(contentWidth: contentWidth))
                .zIndex(4)

            trimHandle(direction: .right)
                .position(x: endX, y: trackHeight / 2)
                .highPriorityGesture(endHandleDragGesture(contentWidth: contentWidth))
                .zIndex(4)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func overviewBar(width: CGFloat) -> some View {
        let safeDuration = max(duration, 0.0001)
        let usableWidth = max(width - overviewHorizontalInset * 2, 1)
        let clipDuration = min(max(currentClipDuration, 1), duration)
        let selectionWidth = min(
            max(CGFloat(clipDuration / safeDuration) * usableWidth, 14),
            usableWidth
        )

        let rawStartX = overviewHorizontalInset + CGFloat(startSeconds / safeDuration) * usableWidth
        let maxStartX = overviewHorizontalInset + usableWidth - selectionWidth
        let clampedStartX = min(max(rawStartX, overviewHorizontalInset), maxStartX)

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))

            overviewBars(width: usableWidth)
                .padding(.horizontal, overviewHorizontalInset)

            RoundedRectangle(cornerRadius: 7)
                .fill(AppColors.primary600.opacity(0.35))
                .frame(width: selectionWidth, height: overviewHeight - 8)
                .offset(x: clampedStartX)

            Rectangle()
                .fill(AppColors.primary600.opacity(0.9))
                .frame(width: 2, height: overviewHeight - 8)
                .offset(x: clampedStartX)

            Rectangle()
                .fill(AppColors.primary600.opacity(0.9))
                .frame(width: 2, height: overviewHeight - 8)
                .offset(x: clampedStartX + selectionWidth - 2)
        }
        .frame(height: overviewHeight)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let target = timeForOverviewX(value.location.x, width: width)
                    moveSelectionCenter(to: target)
                }
        )
    }

    private func overviewBars(width: CGFloat) -> some View {
        let totalBarWidth: CGFloat = 4
        let count = max(Int(width / totalBarWidth), 1)

        return HStack(alignment: .center, spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(
                        width: 2,
                        height: 5 + abs(sin(Double(index) * 0.28)) * (overviewHeight - 10)
                    )
            }
        }
        .frame(width: width, height: overviewHeight - 4, alignment: .leading)
    }

    private func waveformBars(contentWidth: CGFloat) -> some View {
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        let totalBarWidth = barWidth + barSpacing
        let barCount = max(Int(usableWidth / totalBarWidth), 1)

        return HStack(alignment: .center, spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(barOpacity(for: index)))
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .frame(width: usableWidth, height: trackHeight, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
    }

    private func trimHandle(direction: HandleDirection) -> some View {
        let roundedSide: AddSearchDetailHandleRoundedSide = direction == .left ? .left : .right

        return ZStack {
            Rectangle()
                .fill(AppColors.primary600)

            Image(systemName: direction.systemSymbolName)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.black.opacity(0.92))
        }
        .frame(width: handleWidth, height: trackHeight)
        .clipShape(
            AddSearchDetailHandleShape(
                roundedSide: roundedSide,
                radius: handleCornerRadius
            )
        )
        .overlay {
            AddSearchDetailHandleShape(
                roundedSide: roundedSide,
                radius: handleCornerRadius
            )
            .stroke(Color.white.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
    }

    private func startHandleDragGesture(contentWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if startDragBase == nil {
                    startDragBase = startSeconds
                }

                let deltaSeconds = seconds(forTranslation: value.translation.width, contentWidth: contentWidth)
                startSeconds = (startDragBase ?? startSeconds) + deltaSeconds
            }
            .onEnded { _ in
                startDragBase = nil
            }
    }

    private func endHandleDragGesture(contentWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if endDragBase == nil {
                    endDragBase = endSeconds
                }

                let deltaSeconds = seconds(forTranslation: value.translation.width, contentWidth: contentWidth)
                endSeconds = (endDragBase ?? endSeconds) + deltaSeconds
            }
            .onEnded { _ in
                endDragBase = nil
            }
    }

    private func seconds(forTranslation translation: CGFloat, contentWidth: CGFloat) -> Double {
        guard duration > 0 else { return 0 }
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        return Double(translation / usableWidth) * duration
    }

    private func xPosition(for seconds: Double, contentWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return horizontalPadding }
        let clampedSeconds = min(max(seconds, 0), duration)
        let usableWidth = max(contentWidth - horizontalPadding * 2, 1)
        let ratio = clampedSeconds / duration
        return horizontalPadding + CGFloat(ratio) * usableWidth
    }

    private func barHeight(for index: Int) -> CGFloat {
        let primary = abs(sin(Double(index) * 0.43))
        let secondary = abs(cos(Double(index) * 0.17))
        let tertiary = abs(sin(Double(index) * 0.09))
        let mix = min(primary * 0.55 + secondary * 0.3 + tertiary * 0.25, 1)
        return 14 + CGFloat(mix) * (trackHeight - 26)
    }

    private func barOpacity(for index: Int) -> Double {
        let pulse = abs(sin(Double(index) * 0.21))
        return 0.18 + pulse * 0.38
    }

    private var currentClipDuration: Double {
        max(endSeconds - startSeconds, 0)
    }

    private func timeForOverviewX(_ x: CGFloat, width: CGFloat) -> Double {
        guard duration > 0 else { return 0 }
        let usableWidth = max(width - overviewHorizontalInset * 2, 1)
        let clamped = min(max(x - overviewHorizontalInset, 0), usableWidth)
        return Double(clamped / usableWidth) * duration
    }

    private func moveSelectionCenter(to seconds: Double) {
        guard duration > 0 else { return }

        let clipDuration = min(duration, max(currentClipDuration, 1))
        var newStart = seconds - clipDuration / 2
        var newEnd = seconds + clipDuration / 2

        if newStart < 0 {
            newStart = 0
            newEnd = clipDuration
        }
        if newEnd > duration {
            newEnd = duration
            newStart = max(duration - clipDuration, 0)
        }

        onUpdateRange(newStart, newEnd)
    }

    private enum HandleDirection {
        case left
        case right

        var systemSymbolName: String {
            switch self {
            case .left:
                return "chevron.left"
            case .right:
                return "chevron.right"
            }
        }
    }
}

private enum AddSearchDetailHandleRoundedSide {
    case left
    case right
}

private struct AddSearchDetailHandleShape: Shape {
    let roundedSide: AddSearchDetailHandleRoundedSide
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let corners: UIRectCorner
        switch roundedSide {
        case .left:
            corners = [.topLeft, .bottomLeft]
        case .right:
            corners = [.topRight, .bottomRight]
        }

        let bezierPath = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(bezierPath.cgPath)
    }
}

private struct AddSearchDetailVideoCandidateSection: View {
    @ObservedObject var viewModel: AddSearchDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("다른 검색 결과")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white.opacity(0.9))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.s) {
                    ForEach(viewModel.videos) { video in
                        Button {
                            viewModel.selectVideo(video)
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                AsyncImage(url: video.thumbnailURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    case .empty, .failure:
                                        placeholderThumbnail
                                    @unknown default:
                                        placeholderThumbnail
                                    }
                                }
                                .frame(width: 180, height: 102)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text(video.title)
                                    .font(AppFont.paperlogy4Regular(size: 12))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(width: 180, alignment: .leading)
                            }
                            .padding(AppSpacing.xs)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        video.id == viewModel.selectedVideo?.id
                                            ? AppColors.primary600
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var placeholderThumbnail: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.white.opacity(0.72))
            }
    }
}

private struct AddSearchDetailAlbumArtworkView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.white.opacity(0.72))
            }
    }
}

private struct YoutubePlayerView: UIViewRepresentable {
    let videoURL: URL?
    let startSeconds: Double

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

        let targetStart = Double(max(Int(startSeconds.rounded(.down)), 0))
        if context.coordinator.loadedVideoID != videoID {
            context.coordinator.loadedVideoID = videoID
            context.coordinator.lastSyncedStart = targetStart
            webView.loadHTMLString(
                makePlayerHTML(videoID: videoID, startSeconds: targetStart),
                baseURL: appRefererURL
            )
            return
        }

        guard context.coordinator.lastSyncedStart != targetStart else { return }
        context.coordinator.lastSyncedStart = targetStart
        webView.evaluateJavaScript(
            """
            window.kpDesiredStart = \(targetStart);
            if (window.kpPlayerReady && window.kpPlayer) {
                window.kpPlayer.seekTo(window.kpDesiredStart, true);
                window.kpPlayer.playVideo();
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
    }

    private var appRefererURL: URL? {
        guard let appRefererURLString else {
            return nil
        }
        return URL(string: appRefererURLString)
    }

    private func makePlayerHTML(videoID: String, startSeconds: Double) -> String {
        let safeVideoID = escapeForJavaScript(videoID)
        let safeReferer = escapeForJavaScript(appRefererURLString ?? "")
        let initialStart = max(Int(startSeconds.rounded(.down)), 0)

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
                window.kpDesiredStart = \(initialStart);
                window.kpPlayer = null;
                window.kpPlayerReady = false;

                function kpApplyDesiredStart() {
                    if (!window.kpPlayerReady || !window.kpPlayer) {
                        return;
                    }

                    var target = Number(window.kpDesiredStart || 0);
                    if (isNaN(target) || target < 0) {
                        target = 0;
                    }

                    window.kpPlayer.seekTo(target, true);
                    window.kpPlayer.playVideo();
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
                                kpApplyDesiredStart();
                            }
                        }
                    });
                };
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
}
