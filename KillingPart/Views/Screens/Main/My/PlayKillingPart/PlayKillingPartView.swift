import SwiftUI

struct PlayKillingPartView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel: MyCollectionViewModel
    @State private var selectedTrackID: Int?
    @State private var isPlaying = true
    @State private var isPlaylistExpanded = false
    @State private var elapsedInCurrentRange: TimeInterval = 0
    @State private var hasTriggeredInitialLoad = false
    @State private var hasCompletedInitialLoad = false
    @State private var lastTickDate = Date()
    @State private var playerReloadToken = UUID()

    private let playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private let videoAspectRatio: CGFloat = 16 / 9
    private let videoCornerRadius: CGFloat = 16
    private let collapsedPlayerBarHeight: CGFloat = 102
    private let controlsHeight: CGFloat = 86

    init(
        authenticationService: AuthenticationServicing = AuthenticationService(),
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService()
    ) {
        _viewModel = StateObject(
            wrappedValue: MyCollectionViewModel(
                authenticationService: authenticationService,
                userService: userService,
                diaryService: diaryService
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let bottomSafeInset = proxy.safeAreaInsets.bottom
            let playlistHeight = isPlaylistExpanded ? expandedPlaylistHeight : 0
            let bottomPlayerTotalHeight = collapsedPlayerBarHeight
                + controlsHeight
                + playlistHeight
                + bottomSafeInset
                + AppSpacing.s

            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        profileSummaryCard

                        if let currentTrack {
                            currentTrackContent(track: currentTrack)
                        } else if hasCompletedInitialLoad {
                            emptyStateCard
                        } else {
                            loadingStateCard
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(AppFont.paperlogy4Regular(size: 13))
                                .foregroundStyle(.red.opacity(0.95))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, bottomPlayerTotalHeight + AppSpacing.m)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                bottomPlayerPanel(
                    bottomSafeInset: bottomSafeInset,
                    playlistHeight: playlistHeight
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard !hasTriggeredInitialLoad else { return }
            hasTriggeredInitialLoad = true
            resetTickReference()
            Task {
                await viewModel.refetchCollectionDataOnFocus()
                hasCompletedInitialLoad = true
                synchronizeSelectedTrackIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryCreated)) { _ in
            Task {
                await viewModel.refetchCollectionDataOnFocus()
                synchronizeSelectedTrackIfNeeded()
            }
        }
        .onReceive(playbackTimer) { now in
            handlePlaybackTick(now: now)
        }
        .onChange(of: playlistTrackIDs) { _ in
            synchronizeSelectedTrackIfNeeded()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                playerReloadToken = UUID()
            }
            resetTickReference()
        }
    }

    private var playlistTracks: [PlayKillingPartTrack] {
        viewModel.myFeeds.map(makeTrack(from:))
    }

    private var playlistTrackIDs: [Int] {
        playlistTracks.map(\.id)
    }

    private var currentTrack: PlayKillingPartTrack? {
        guard !playlistTracks.isEmpty else { return nil }

        if
            let selectedTrackID,
            let matchedTrack = playlistTracks.first(where: { $0.id == selectedTrackID })
        {
            return matchedTrack
        }

        return playlistTracks.first
    }

    private var currentTrackIndex: Int {
        guard let currentTrack else { return 0 }
        return playlistTracks.firstIndex(where: { $0.id == currentTrack.id }) ?? 0
    }

    private var nextTrack: PlayKillingPartTrack? {
        guard !playlistTracks.isEmpty else { return nil }
        let nextIndex = currentTrackIndex + 1
        guard playlistTracks.indices.contains(nextIndex) else { return nil }
        return playlistTracks[nextIndex]
    }

    private var expandedPlaylistHeight: CGFloat {
        let rowHeight: CGFloat = 62
        let estimated = CGFloat(max(playlistTracks.count, 1)) * rowHeight
        return min(max(estimated, 120), 284)
    }

    private var profileSummaryCard: some View {
        HStack(spacing: AppSpacing.s) {
            MyCollectionProfileImageView(
                profileImageURL: viewModel.profileImageURL,
                size: 56,
                iconSize: 22
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.displayName)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(Color.kpPrimary)
                    .lineLimit(1)

                Text(viewModel.displayTag)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color.kpPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func currentTrackContent(track: PlayKillingPartTrack) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Group {
                if let videoURL = track.videoURL {
                    YoutubePlayerView(
                        videoURL: videoURL,
                        startSeconds: track.startSeconds,
                        endSeconds: track.endSeconds,
                        isPlaying: isPlaying
                    )
                    .id("\(track.id)-\(playerReloadToken)")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(videoAspectRatio, contentMode: .fit)
                    .allowsHitTesting(false)
                    .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: videoCornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                } else {
                    RoundedRectangle(cornerRadius: videoCornerRadius)
                        .fill(Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(videoAspectRatio, contentMode: .fit)
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(AppColors.primary600)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(track.displayTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 20))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(track.displayArtist)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.xs)

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Text("킬링파트 일기")
                    .font(AppFont.paperlogy6SemiBold(size: 13))
                    .foregroundStyle(AppColors.primary600.opacity(0.92))

                Text(track.displayContent)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.m)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
        }
    }

    private var loadingStateCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay {
                VStack(spacing: AppSpacing.s) {
                    ProgressView()
                        .tint(AppColors.primary600)
                    Text("재생 목록을 불러오는 중...")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.white.opacity(0.74))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private var emptyStateCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .overlay {
                VStack(spacing: AppSpacing.s) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppColors.primary600)

                    Text("재생할 음악 다이어리가 없어요.")
                        .font(AppFont.paperlogy5Medium(size: 14))
                        .foregroundStyle(.white.opacity(0.76))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    @ViewBuilder
    private func bottomPlayerPanel(bottomSafeInset: CGFloat, playlistHeight: CGFloat) -> some View {
        VStack(spacing: AppSpacing.s) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isPlaylistExpanded.toggle()
                }
            } label: {
                playerSummaryBar
            }
            .buttonStyle(.plain)
            .disabled(currentTrack == nil)
            .opacity(currentTrack == nil ? 0.5 : 1)

            if isPlaylistExpanded {
                playlistView
                    .frame(height: playlistHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            playbackControls
                .frame(height: controlsHeight)
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, bottomSafeInset + AppSpacing.s)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.86),
                    Color.black.opacity(0.74)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.bottom, AppSpacing.xs)
        .animation(.easeInOut(duration: 0.2), value: isPlaylistExpanded)
    }

    private var playerSummaryBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.s) {
                Text(currentTrack?.displayTitle ?? "재생할 곡 없음")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: isPlaylistExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let currentTrack {
                playbackRangeBar(track: currentTrack)
                    .frame(height: 20)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 3)
            }

            Text("다음 곡: \(nextTrack?.displayTitle ?? "마지막 곡")")
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(.white.opacity(0.76))
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.s)
        .padding(.vertical, AppSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private func playbackRangeBar(track: PlayKillingPartTrack) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let startX = width * track.startProgress
            let endX = width * track.endProgress
            let segmentWidth = max(endX - startX, 2)
            let playheadX = width * track.playheadProgress(elapsedInCurrentRange: elapsedInCurrentRange)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.26))
                    .frame(height: 3)

                Capsule()
                    .fill(AppColors.primary600)
                    .frame(width: segmentWidth, height: 8)
                    .offset(x: startX)

                Circle()
                    .fill(Color.white)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .stroke(AppColors.primary600, lineWidth: 1)
                    }
                    .offset(x: min(max(playheadX - 4.5, 0), width - 9))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var playlistView: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xs) {
                ForEach(Array(playlistTracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        selectTrack(at: index)
                    } label: {
                        HStack(spacing: AppSpacing.s) {
                            Text("\(index + 1)")
                                .font(AppFont.paperlogy5Medium(size: 12))
                                .foregroundStyle(AppColors.primary600)
                                .frame(width: 18, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(track.displayTitle)
                                    .font(AppFont.paperlogy5Medium(size: 13))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                Text(track.displayArtist)
                                    .font(AppFont.paperlogy4Regular(size: 11))
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Text("\(track.startLabel) - \(track.endLabel)")
                                .font(AppFont.paperlogy4Regular(size: 10))
                                .foregroundStyle(AppColors.primary600.opacity(0.9))
                        }
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(track.id == currentTrack?.id ? AppColors.primary600.opacity(0.16) : Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var playbackControls: some View {
        HStack(spacing: AppSpacing.xl) {
            controlButton(symbol: "backward.fill", action: moveToPreviousTrack)

            Button {
                togglePlayState()
            } label: {
                Circle()
                    .fill(AppColors.primary600)
                    .frame(width: 58, height: 58)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: isPlaying ? 0 : 2)
                    }
            }
            .buttonStyle(.plain)
            .disabled(currentTrack == nil)
            .opacity(currentTrack == nil ? 0.5 : 1)

            controlButton(symbol: "forward.fill", action: moveToNextTrack)
        }
        .frame(maxWidth: .infinity)
    }

    private func controlButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .disabled(currentTrack == nil)
        .opacity(currentTrack == nil ? 0.5 : 1)
    }

    private func togglePlayState() {
        guard currentTrack != nil else { return }
        isPlaying.toggle()
        resetTickReference()
    }

    private func moveToPreviousTrack() {
        guard !playlistTracks.isEmpty else { return }
        let previousIndex = max(currentTrackIndex - 1, 0)
        selectTrack(at: previousIndex)
    }

    private func moveToNextTrack() {
        guard !playlistTracks.isEmpty else { return }
        let nextIndex = currentTrackIndex + 1
        guard playlistTracks.indices.contains(nextIndex) else {
            isPlaying = false
            elapsedInCurrentRange = 0
            return
        }
        selectTrack(at: nextIndex)
    }

    private func selectTrack(at index: Int) {
        guard playlistTracks.indices.contains(index) else { return }
        let selectedTrack = playlistTracks[index]
        guard selectedTrackID != selectedTrack.id else {
            elapsedInCurrentRange = 0
            resetTickReference()
            return
        }

        selectedTrackID = selectedTrack.id
        elapsedInCurrentRange = 0
        playerReloadToken = UUID()
        resetTickReference()
    }

    private func synchronizeSelectedTrackIfNeeded() {
        guard !playlistTracks.isEmpty else {
            selectedTrackID = nil
            elapsedInCurrentRange = 0
            isPlaying = false
            return
        }

        if !isPlaying {
            isPlaying = true
        }

        if
            let selectedTrackID,
            let selectedTrack = playlistTracks.first(where: { $0.id == selectedTrackID })
        {
            if elapsedInCurrentRange > selectedTrack.rangeDuration {
                elapsedInCurrentRange = 0
            }
            return
        }

        selectedTrackID = playlistTracks[0].id
        elapsedInCurrentRange = 0
        playerReloadToken = UUID()
        resetTickReference()
    }

    private func handlePlaybackTick(now: Date) {
        defer {
            lastTickDate = now
        }

        guard isPlaying else { return }
        guard let currentTrack else { return }

        let delta = now.timeIntervalSince(lastTickDate)
        guard delta > 0 else { return }

        let updatedElapsed = elapsedInCurrentRange + delta
        if updatedElapsed < currentTrack.rangeDuration {
            elapsedInCurrentRange = updatedElapsed
            return
        }

        elapsedInCurrentRange = 0
        moveToNextTrack()
    }

    private func resetTickReference() {
        lastTickDate = Date()
    }

    private func makeTrack(from feed: DiaryFeedModel) -> PlayKillingPartTrack {
        let startSeconds = parsedSeconds(from: feed.start) ?? 0
        let endSeconds = max(parsedSeconds(from: feed.end) ?? startSeconds, startSeconds + 0.1)
        let totalSeconds = max(parsedSeconds(from: feed.totalDuration) ?? 0, endSeconds, 1)

        return PlayKillingPartTrack(
            feed: feed,
            startSeconds: startSeconds,
            endSeconds: endSeconds,
            totalSeconds: totalSeconds,
            videoURL: resolvedVideoURL(from: feed.videoUrl)
        )
    }

    private func parsedSeconds(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let raw = Double(trimmed) {
            return max(raw, 0)
        }

        let sanitized = trimmed.replacingOccurrences(of: "초", with: "")
        if sanitized.contains(":") {
            let parts = sanitized.split(separator: ":").map(String.init)
            guard
                parts.count == 2,
                let minutes = Double(parts[0]),
                let seconds = Double(parts[1])
            else {
                return nil
            }
            return max((minutes * 60) + seconds, 0)
        }

        if let raw = Double(sanitized) {
            return max(raw, 0)
        }

        return nil
    }

    private func resolvedVideoURL(from rawVideoURL: String) -> URL? {
        let trimmed = rawVideoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedURLText: String
        if isLikelyYouTubeVideoID(trimmed) {
            normalizedURLText = "https://www.youtube.com/embed/\(trimmed)?playsinline=1"
        } else {
            normalizedURLText = trimmed
        }

        if let parsed = URL(string: normalizedURLText), parsed.scheme != nil {
            return parsed
        }

        if normalizedURLText.hasPrefix("//") {
            return URL(string: "https:\(normalizedURLText)")
        }

        return URL(string: "https://\(normalizedURLText)")
    }

    private func isLikelyYouTubeVideoID(_ value: String) -> Bool {
        if value.hasPrefix("//") {
            return false
        }

        if let components = URLComponents(string: value),
           components.scheme != nil || components.host != nil {
            return false
        }

        return !value.contains("/")
            && !value.contains("?")
            && !value.contains("&")
            && !value.contains("=")
            && !value.contains(".")
    }
}

private struct PlayKillingPartTrack: Identifiable {
    let feed: DiaryFeedModel
    let startSeconds: Double
    let endSeconds: Double
    let totalSeconds: Double
    let videoURL: URL?

    var id: Int { feed.id }

    var displayTitle: String {
        let trimmed = feed.musicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "제목 없음" : trimmed
    }

    var displayArtist: String {
        let trimmed = feed.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "아티스트 정보 없음" : trimmed
    }

    var displayContent: String {
        let trimmed = feed.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "작성된 킬링파트 일기가 없어요." : trimmed
    }

    var startLabel: String {
        TimeFormatter.minuteSecondText(from: startSeconds)
    }

    var endLabel: String {
        TimeFormatter.minuteSecondText(from: endSeconds)
    }

    var rangeDuration: Double {
        max(endSeconds - startSeconds, 0.1)
    }

    var startProgress: CGFloat {
        CGFloat(min(max(startSeconds / totalSeconds, 0), 1))
    }

    var endProgress: CGFloat {
        CGFloat(min(max(endSeconds / totalSeconds, startSeconds / totalSeconds), 1))
    }

    func playheadProgress(elapsedInCurrentRange: TimeInterval) -> CGFloat {
        let absoluteSeconds = min(startSeconds + elapsedInCurrentRange, endSeconds)
        return CGFloat(min(max(absoluteSeconds / totalSeconds, 0), 1))
    }
}
