import SwiftUI

struct FeedSectionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: FeedViewModel
    let isParentActive: Bool
    let makeCollectionViewModel: (UserModel) -> SocialMyCollectionViewModel
    @State private var currentPageIndex = 0
    @State private var elapsedInCurrentRange: TimeInterval = 0
    @State private var isViewActive = false
    @State private var previousFeedCount = 0
    @State private var playbackFocusToken = 0
    @State private var selectedProfileUser: UserModel?
    @State private var isProfileNavigationActive = false
    @State private var activeLikeUsersSheet: LikeUsersSheetContext?
    @State private var activeDiaryReportSheet: DiaryReportSheetContext?
    @State private var pendingLikeUserDestination: UserModel?
    @State private var likeUsersSearchText = ""
    @State private var diaryReportContent = ""
    @StateObject private var interactionFeedbackPresenter = SocialInteractionFeedbackPresenter()

    private let playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = max(geometry.safeAreaInsets.bottom, AppSpacing.m) + AppSpacing.xl
            Group {
                if viewModel.isLoadingInitial {
                    ProgressView()
                        .tint(AppColors.primary600)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, AppSpacing.xl)
                } else if let errorMessage = viewModel.errorMessage, viewModel.feeds.isEmpty {
                    VStack(spacing: AppSpacing.s) {
                        Text(errorMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Button("다시 시도") {
                            Task { await viewModel.refresh() }
                        }
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, AppSpacing.xl)
                } else if viewModel.feeds.isEmpty {
                    Text("표시할 피드가 없어요.")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, AppSpacing.xl)
                } else {
                    feedPager
                }
            }
            .padding(.bottom, bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .center) {
                SocialInteractionFeedbackOverlay(feedback: interactionFeedbackPresenter.activeFeedback)
            }
        }
        .onAppear {
            isViewActive = true
            previousFeedCount = viewModel.feeds.count
            handleFocusActivated()
        }
        .onDisappear {
            isViewActive = false
            interactionFeedbackPresenter.clear()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                handleFocusActivated()
            }
        }
        .onChange(of: isParentActive) { isParentActive in
            guard isParentActive else { return }
            handleFocusActivated()
        }
        .onChange(of: viewModel.feeds.count) { newCount in
            let hasAppendedFeed = newCount > previousFeedCount
            previousFeedCount = newCount
            if newCount == 0 {
                currentPageIndex = 0
                elapsedInCurrentRange = 0
            } else if currentPageIndex >= newCount {
                currentPageIndex = max(newCount - 1, 0)
            }
            if hasAppendedFeed && isPlaybackActive {
                bumpPlaybackFocusToken()
            }
        }
        .onChange(of: activeLikeUsersSheet) { sheetContext in
            if sheetContext == nil {
                viewModel.clearLikeUsersState()
                likeUsersSearchText = ""
                guard let pendingLikeUserDestination else { return }
                self.pendingLikeUserDestination = nil
                selectedProfileUser = pendingLikeUserDestination
                DispatchQueue.main.async {
                    isProfileNavigationActive = true
                }
            }
        }
        .onChange(of: activeDiaryReportSheet) { sheetContext in
            if sheetContext == nil {
                diaryReportContent = ""
                viewModel.clearDiaryReportState()
            }
        }
        .sheet(item: $activeLikeUsersSheet) { sheetContext in
            SocialDiaryLikeUsersSheet(
                title: "좋아요한 사용자",
                searchText: $likeUsersSearchText,
                users: viewModel.likeUsers,
                isLoading: viewModel.isLoadingLikeUsers,
                isLoadingMore: viewModel.isLoadingMoreLikeUsers,
                errorMessage: viewModel.likeUsersErrorMessage,
                emptyMessage: "좋아요를 누른 사용자가 아직 없어요.",
                onSearchSubmit: {
                    Task {
                        await viewModel.loadLikeUsers(
                            diaryId: sheetContext.diaryId,
                            searchCond: normalizedLikeUsersSearchCond
                        )
                    }
                },
                onSearchClear: {
                    likeUsersSearchText = ""
                    Task {
                        await viewModel.loadLikeUsers(diaryId: sheetContext.diaryId, searchCond: nil)
                    }
                },
                onRetry: {
                    Task {
                        await viewModel.retryLikeUsersLoading()
                    }
                },
                onUserAppear: { userId in
                    Task {
                        await viewModel.loadMoreLikeUsersIfNeeded(currentUserId: userId)
                    }
                },
                onUserTap: { user in
                    pendingLikeUserDestination = user
                    activeLikeUsersSheet = nil
                }
            )
        }
        .sheet(item: $activeDiaryReportSheet) { sheetContext in
            SocialDiaryReportSheet(
                reportReason: $diaryReportContent,
                isSubmitting: viewModel.isReportingDiary,
                errorMessage: viewModel.reportErrorMessage,
                onCancel: {
                    activeDiaryReportSheet = nil
                },
                onSubmit: {
                    Task {
                        let isSuccess = await viewModel.reportDiary(
                            diaryId: sheetContext.diaryId,
                            content: diaryReportContent
                        )
                        if isSuccess {
                            activeDiaryReportSheet = nil
                        }
                    }
                }
            )
        }
    }

    private var feedPager: some View {
        VStack(spacing: AppSpacing.s) {
            TabView(selection: $currentPageIndex) {
                ForEach(viewModel.feeds.indices, id: \.self) { index in
                    let feed = viewModel.feeds[index]
                    let isActive = index == currentPageIndex && isPlaybackActive
                    // 현재 페이지와 인접 페이지를 미리 로드해 스와이프 전환 시 버벅임을 줄인다.
                    let shouldLoadPlayer = abs(index - currentPageIndex) <= 1

                    SocialFeedPageCardView(
                        feed: feed,
                        isVideoPlaying: isActive,
                        playbackFocusToken: isActive ? playbackFocusToken : 0,
                        elapsedInCurrentRange: isActive ? elapsedInCurrentRange : 0,
                        shouldLoadPlayer: shouldLoadPlayer,
                        onProfileTap: {
                            guard feed.userId > 0 else { return }
                            selectedProfileUser = makeUserModel(from: feed)
                            isProfileNavigationActive = true
                        },
                        onLikeTap: {
                            handleLikeTap(diaryId: feed.diaryId)
                        },
                        onLikeLongPress: {
                            likeUsersSearchText = ""
                            activeLikeUsersSheet = LikeUsersSheetContext(diaryId: feed.diaryId)
                            Task {
                                await viewModel.loadLikeUsers(diaryId: feed.diaryId, searchCond: nil)
                            }
                        },
                        onStoreTap: {
                            handleStoreTap(diaryId: feed.diaryId)
                        },
                        onReportTap: {
                            diaryReportContent = ""
                            viewModel.clearDiaryReportState()
                            activeDiaryReportSheet = DiaryReportSheetContext(diaryId: feed.diaryId)
                        },
                        onBlockTap: {
                            guard feed.userId > 0 else { return }
                            Task {
                                _ = await viewModel.blockUser(blockedId: feed.userId)
                            }
                        },
                        onDoubleTap: {
                            handleDoubleTapLike(diaryId: feed.diaryId)
                        },
                        onVideoPlaybackEnded: {
                            guard currentPageIndex == index else { return }
                            handleVideoPlaybackEnded(currentIndex: index, feed: feed)
                        }
                    )
                    .tag(index)
                    .padding(.top, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.xs)
                    .onAppear {
                        Task { 
                            await viewModel.loadMoreIfNeeded(currentDiaryId: feed.diaryId)
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(AppColors.primary600)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(playbackTimer) { _ in
            guard isPlaybackActive else { return }
            elapsedInCurrentRange += 0.25
        }
        .onChange(of: currentPageIndex) { _ in
            elapsedInCurrentRange = 0
            bumpPlaybackFocusToken()
        }
        .onChange(of: isProfileNavigationActive) { isActive in
            if !isActive {
                selectedProfileUser = nil
                handleFocusActivated()
            }
        }
        .background(profileNavigationLink)
    }

    private var isPlaybackActive: Bool {
        isViewActive && isParentActive && scenePhase == .active
    }

    private var profileNavigationLink: some View {
        NavigationLink(
            isActive: $isProfileNavigationActive,
            destination: {
                if let selectedProfileUser {
                    SocialMyCollectionView(
                        viewModel: makeCollectionViewModel(selectedProfileUser)
                    )
                } else {
                    EmptyView()
                }
            },
            label: {
                EmptyView()
            }
        )
        .hidden()
    }

    private func bumpPlaybackFocusToken() {
        playbackFocusToken &+= 1
    }

    private func handleFocusActivated() {
        guard isPlaybackActive else { return }
        elapsedInCurrentRange = 0
        bumpPlaybackFocusToken()
        Task {
            await viewModel.refreshLoadedFeedInteractionsIfNeeded()
        }
    }

    private var normalizedLikeUsersSearchCond: String? {
        let trimmed = likeUsersSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func handleLikeTap(diaryId: Int) {
        guard let feed = feed(for: diaryId) else { return }
        let feedback: SocialInteractionFeedbackKind = feed.isLiked ? .likeRemoved : .likeAdded
        interactionFeedbackPresenter.show(feedback)
        Task {
            await viewModel.toggleLike(diaryId: diaryId)
        }
    }

    private func handleStoreTap(diaryId: Int) {
        guard let feed = feed(for: diaryId) else { return }
        let feedback: SocialInteractionFeedbackKind = feed.isStored ? .storeRemoved : .storeAdded
        interactionFeedbackPresenter.show(feedback)
        Task {
            await viewModel.toggleStore(diaryId: diaryId)
        }
    }

    private func handleDoubleTapLike(diaryId: Int) {
        guard let feed = feed(for: diaryId) else { return }
        guard !feed.isLiked else {
            interactionFeedbackPresenter.show(.alreadyLiked)
            return
        }

        interactionFeedbackPresenter.show(.likeAdded)
        Task {
            await viewModel.toggleLike(diaryId: diaryId)
        }
    }

    private func feed(for diaryId: Int) -> DiaryFeedModel? {
        viewModel.feeds.first(where: { $0.diaryId == diaryId })
    }

    private func makeUserModel(from feed: DiaryFeedModel) -> UserModel {
        let username = trimmedString(feed.username, fallback: "킬링파트 사용자")
        let tag = normalizeTag(trimmedString(feed.tag, fallback: "killingpart_user"))
        let profileImageUrl = trimmedString(feed.profileImageUrl, fallback: "")
        return UserModel(
            userId: feed.userId,
            username: username,
            tag: tag,
            identifier: String(feed.userId),
            profileImageUrl: profileImageUrl,
            userRoleType: "USER",
            socialType: "UNKNOWN",
            isMyPick: feed.isMyPick
        )
    }

    private func trimmedString(_ raw: String?, fallback: String) -> String {
        guard
            let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return fallback
        }
        return raw
    }

    private func normalizeTag(_ rawTag: String) -> String {
        if rawTag.hasPrefix("@") {
            return String(rawTag.dropFirst())
        }
        return rawTag
    }

    private struct LikeUsersSheetContext: Identifiable, Equatable {
        let diaryId: Int
        var id: Int { diaryId }
    }

    private struct DiaryReportSheetContext: Identifiable, Equatable {
        let diaryId: Int
        var id: Int { diaryId }
    }
     
    private func handleVideoPlaybackEnded(currentIndex: Int, feed: DiaryFeedModel) {
        Task {
            let nextIndex = currentIndex + 1
            
            // 미리 다음 페이지 데이터 로드
            if nextIndex >= viewModel.feeds.count - 2 {
                await viewModel.loadMoreIfNeeded(currentDiaryId: feed.diaryId)
            }
            
            // 데이터 로딩 대기
            var waitCount = 0
            while viewModel.isLoadingMore && waitCount < 20 {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                waitCount += 1
            }
            
            guard nextIndex < viewModel.feeds.count else { return }
            
            await MainActor.run {
                elapsedInCurrentRange = 0
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPageIndex = nextIndex
                }
            }
        }
    }
}
