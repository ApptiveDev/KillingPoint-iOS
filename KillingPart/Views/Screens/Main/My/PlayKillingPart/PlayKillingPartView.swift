import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct PlayKillingPartView: View {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var viewModel: MyCollectionViewModel
    @StateObject private var playViewModel: PlayKillingPartViewModel
    @State private var selectedTrackID: Int?
    @State private var isPlaying = true
    @State private var isPlaylistExpanded = false
    @State private var elapsedInCurrentRange: TimeInterval = 0
    @State private var orderedDiaryIDs: [Int] = []
    @State private var draggedTrackID: Int?
    @State private var lastReorderDate = Date.distantPast
    @State private var hasTriggeredInitialLoad = false
    @State private var hasCompletedInitialLoad = false
    @State private var lastTickDate = Date()
    @State private var playerReloadToken = UUID()

    private let playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private let controlsHeight: CGFloat = 98
    private let reorderThrottleInterval: TimeInterval = 0.18
    private let reorderAnimationDuration: Double = 0.24

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
        _playViewModel = StateObject(
            wrappedValue: PlayKillingPartViewModel(diaryService: diaryService)
        )
    }

    var body: some View {
        ScrollView {
            playbackContentContainer
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(playViewModel.isEditMode && isPlaylistExpanded)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            let playlistHeight = isPlaylistExpanded ? expandedPlaylistHeight : 0
            bottomPlayerPanel(playlistHeight: playlistHeight)
                .padding(.bottom, AppSpacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            guard !hasTriggeredInitialLoad else { return }
            hasTriggeredInitialLoad = true
            resetTickReference()
            Task {
                await loadAllDiaryFeedsForPlayback()
                hasCompletedInitialLoad = true
                reconcileOrderedDiaryIDsIfNeeded()
                synchronizeSelectedTrackIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryCreated)) { _ in
            Task {
                await loadAllDiaryFeedsForPlayback()
                reconcileOrderedDiaryIDsIfNeeded()
                synchronizeSelectedTrackIfNeeded()
            }
        }
        .onReceive(playbackTimer) { now in
            handlePlaybackTick(now: now)
        }
        .onChange(of: basePlaylistTrackIDs) { _ in
            reconcileOrderedDiaryIDsIfNeeded()
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
        .onChange(of: playViewModel.isEditMode) { isEditing in
            if !isEditing {
                draggedTrackID = nil
                lastReorderDate = .distantPast
            }
        }
    }

    @ViewBuilder
    private var playbackContentContainer: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            PlayKillingPartProfileSummaryCard(
                profileImageURL: viewModel.profileImageURL,
                displayName: viewModel.displayName,
                displayTag: viewModel.displayTag
            )

            if let currentTrack {
                PlayKillingPartCurrentTrackContent(
                    track: currentTrack,
                    isPlaying: isPlaying,
                    playerReloadToken: playerReloadToken
                )
            } else if hasCompletedInitialLoad {
                PlayKillingPartEmptyStateCard()
            } else {
                PlayKillingPartLoadingStateCard()
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = playViewModel.errorMessage {
                Text(errorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.m)
        .background(Color.black.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }

    private var basePlaylistTracks: [PlayKillingPartTrack] {
        viewModel.myFeeds.map(makeTrack(from:))
    }

    private var basePlaylistTrackIDs: [Int] {
        basePlaylistTracks.map(\.id)
    }

    private var playlistTracks: [PlayKillingPartTrack] {
        guard !orderedDiaryIDs.isEmpty else { return basePlaylistTracks }

        let trackByID = Dictionary(uniqueKeysWithValues: basePlaylistTracks.map { ($0.id, $0) })
        let orderedTracks = orderedDiaryIDs.compactMap { trackByID[$0] }
        if orderedTracks.count == basePlaylistTracks.count {
            return orderedTracks
        }

        let orderedTrackIDs = Set(orderedTracks.map(\.id))
        let remainingTracks = basePlaylistTracks.filter { !orderedTrackIDs.contains($0.id) }
        return orderedTracks + remainingTracks
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

    @ViewBuilder
    private func bottomPlayerPanel(playlistHeight: CGFloat) -> some View {
        VStack(spacing: AppSpacing.m) {
            PlayKillingPartPlayerSummaryBar(
                currentTrack: currentTrack,
                nextTrack: nextTrack,
                isPlaylistExpanded: isPlaylistExpanded,
                isSavingOrder: playViewModel.isSavingOrder,
                isEditMode: playViewModel.isEditMode,
                isPlaylistEmpty: playlistTracks.isEmpty,
                elapsedInCurrentRange: elapsedInCurrentRange,
                onEditButtonTap: handlePlaylistEditButtonTap
            )
                .contentShape(Rectangle())
                .gesture(
                    TapGesture().onEnded {
                        togglePlaylistExpansion()
                    },
                    including: .gesture
                )
                .allowsHitTesting(currentTrack != nil && !playViewModel.isSavingOrder)
                .opacity((currentTrack == nil || playViewModel.isSavingOrder) ? 0.5 : 1)

            if isPlaylistExpanded {
                playlistView
                    .frame(height: playlistHeight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            PlayKillingPartPlaybackControls(
                isPlaying: isPlaying,
                isDisabled: currentTrack == nil || playViewModel.isEditMode || playViewModel.isSavingOrder,
                onPrevious: moveToPreviousTrack,
                onTogglePlay: togglePlayState,
                onNext: moveToNextTrack
            )
                .frame(height: controlsHeight)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.m)
        .padding(.bottom, AppSpacing.m)
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
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
        .padding(.bottom, AppSpacing.xs)
    }

    private var playlistView: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: AppSpacing.xs) {
                    playlistEdgeDropZone(position: .top, scrollProxy: scrollProxy)

                    ForEach(Array(playlistTracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            guard !playViewModel.isEditMode else { return }
                            selectTrack(at: index)
                        } label: {
                            PlayKillingPartPlaylistRow(
                                track: track,
                                isCurrentTrack: track.id == currentTrack?.id,
                                isPlaying: isPlaying,
                                isEditMode: playViewModel.isEditMode,
                                isBeingDragged: playViewModel.isEditMode && draggedTrackID == track.id
                            ) { trackID in
                                makeTrackDragItemProvider(trackID: trackID)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(track.id)
                        .onDrop(
                            of: [UTType.text.identifier],
                            delegate: PlayKillingPartReorderDropDelegate(
                                targetTrackID: track.id,
                                orderedDiaryIDs: $orderedDiaryIDs,
                                draggedTrackID: $draggedTrackID,
                                lastReorderDate: $lastReorderDate,
                                minimumReorderInterval: reorderThrottleInterval,
                                reorderAnimationDuration: reorderAnimationDuration,
                                isEditing: playViewModel.isEditMode,
                                onTrackHovered: { hoveredTrackID in
                                    withAnimation(.easeInOut(duration: 0.12)) {
                                        scrollProxy.scrollTo(hoveredTrackID, anchor: .center)
                                    }
                                }
                            )
                        )
                    }

                    playlistEdgeDropZone(position: .bottom, scrollProxy: scrollProxy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func playlistEdgeDropZone(
        position: PlayKillingPartDropEdge,
        scrollProxy: ScrollViewProxy
    ) -> some View {
        Color.clear
            .frame(height: 20)
            .contentShape(Rectangle())
            .onDrop(
                of: [UTType.text.identifier],
                delegate: PlayKillingPartEdgeDropDelegate(
                    edge: position,
                    orderedDiaryIDs: $orderedDiaryIDs,
                    draggedTrackID: $draggedTrackID,
                    lastReorderDate: $lastReorderDate,
                    minimumReorderInterval: reorderThrottleInterval,
                    reorderAnimationDuration: reorderAnimationDuration,
                    isEditing: playViewModel.isEditMode,
                    onEdgeReached: { edge in
                        guard !orderedDiaryIDs.isEmpty else { return }
                        let targetID = edge == .top ? orderedDiaryIDs.first : orderedDiaryIDs.last
                        guard let targetID else { return }
                        withAnimation(.easeInOut(duration: 0.12)) {
                            scrollProxy.scrollTo(
                                targetID,
                                anchor: edge == .top ? .top : .bottom
                            )
                        }
                    }
                )
            )
    }

    private func beginTrackDrag(trackID: Int) {
        draggedTrackID = trackID
        lastReorderDate = .distantPast
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    private func makeTrackDragItemProvider(trackID: Int) -> NSItemProvider {
        beginTrackDrag(trackID: trackID)
        let itemProvider = PlayKillingPartDragItemProvider(object: NSString(string: "\(trackID)"))
        itemProvider.onDragEnded = { [trackID] in
            DispatchQueue.main.async {
                if draggedTrackID == trackID {
                    draggedTrackID = nil
                }
            }
        }
        return itemProvider
    }

    private func togglePlaylistExpansion() {
        guard !(playViewModel.isEditMode && isPlaylistExpanded) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            isPlaylistExpanded.toggle()
        }
    }

    private func handlePlaylistEditButtonTap() {
        if playViewModel.isEditMode {
            Task {
                let isSuccess = await playViewModel.completeEditing(with: orderedDiaryIDs)
                guard isSuccess else { return }
                draggedTrackID = nil
            }
            return
        }

        playViewModel.beginEditing()
    }

    private func reconcileOrderedDiaryIDsIfNeeded() {
        let sourceIDs = basePlaylistTrackIDs
        guard !sourceIDs.isEmpty else {
            orderedDiaryIDs = []
            return
        }

        guard playViewModel.isEditMode else {
            if orderedDiaryIDs != sourceIDs {
                orderedDiaryIDs = sourceIDs
            }
            return
        }

        let sourceSet = Set(sourceIDs)
        var reconciledIDs = orderedDiaryIDs.filter { sourceSet.contains($0) }
        for sourceID in sourceIDs where !reconciledIDs.contains(sourceID) {
            reconciledIDs.append(sourceID)
        }

        if reconciledIDs != orderedDiaryIDs {
            orderedDiaryIDs = reconciledIDs
        }
    }

    private func togglePlayState() {
        guard currentTrack != nil else { return }
        guard !playViewModel.isEditMode else { return }
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

    private func loadAllDiaryFeedsForPlayback() async {
        await viewModel.refetchCollectionDataOnFocus()

        var previousFeedCount = -1
        var iteration = 0
        while previousFeedCount != viewModel.myFeeds.count, iteration < 200 {
            previousFeedCount = viewModel.myFeeds.count
            await viewModel.loadMoreMyFeedsFromBottomIfNeeded()
            iteration += 1
        }
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

private final class PlayKillingPartDragItemProvider: NSItemProvider {
    var onDragEnded: (() -> Void)?

    deinit {
        onDragEnded?()
    }
}

struct PlayKillingPartTrack: Identifiable {
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

private struct PlayKillingPartReorderDropDelegate: DropDelegate {
    let targetTrackID: Int
    @Binding var orderedDiaryIDs: [Int]
    @Binding var draggedTrackID: Int?
    @Binding var lastReorderDate: Date
    let minimumReorderInterval: TimeInterval
    let reorderAnimationDuration: Double
    let isEditing: Bool
    let onTrackHovered: (Int) -> Void

    func dropEntered(info: DropInfo) {
        guard isEditing else { return }
        guard let draggedTrackID else { return }
        guard draggedTrackID != targetTrackID else { return }
        let now = Date()
        guard now.timeIntervalSince(lastReorderDate) >= minimumReorderInterval else { return }
        guard
            let sourceIndex = orderedDiaryIDs.firstIndex(of: draggedTrackID),
            let destinationIndex = orderedDiaryIDs.firstIndex(of: targetTrackID)
        else {
            return
        }

        if orderedDiaryIDs[destinationIndex] != draggedTrackID {
            withAnimation(.easeInOut(duration: reorderAnimationDuration)) {
                orderedDiaryIDs.move(
                    fromOffsets: IndexSet(integer: sourceIndex),
                    toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex
                )
            }
            lastReorderDate = now
        }
        onTrackHovered(targetTrackID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isEditing ? DropProposal(operation: .move) : DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTrackID = nil
        lastReorderDate = .distantPast
        return isEditing
    }
}

private enum PlayKillingPartDropEdge {
    case top
    case bottom
}

private struct PlayKillingPartEdgeDropDelegate: DropDelegate {
    let edge: PlayKillingPartDropEdge
    @Binding var orderedDiaryIDs: [Int]
    @Binding var draggedTrackID: Int?
    @Binding var lastReorderDate: Date
    let minimumReorderInterval: TimeInterval
    let reorderAnimationDuration: Double
    let isEditing: Bool
    let onEdgeReached: (PlayKillingPartDropEdge) -> Void

    func dropEntered(info: DropInfo) {
        guard isEditing else { return }
        guard let draggedTrackID else { return }
        let now = Date()
        guard now.timeIntervalSince(lastReorderDate) >= minimumReorderInterval else { return }
        guard let sourceIndex = orderedDiaryIDs.firstIndex(of: draggedTrackID) else { return }

        let destinationOffset: Int = edge == .top ? 0 : orderedDiaryIDs.count
        let destinationIndex: Int = edge == .top ? 0 : max(orderedDiaryIDs.count - 1, 0)

        if sourceIndex != destinationIndex {
            withAnimation(.easeInOut(duration: reorderAnimationDuration)) {
                orderedDiaryIDs.move(
                    fromOffsets: IndexSet(integer: sourceIndex),
                    toOffset: destinationOffset
                )
            }
            lastReorderDate = now
        }

        onEdgeReached(edge)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        isEditing ? DropProposal(operation: .move) : DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTrackID = nil
        lastReorderDate = .distantPast
        return isEditing
    }
}
