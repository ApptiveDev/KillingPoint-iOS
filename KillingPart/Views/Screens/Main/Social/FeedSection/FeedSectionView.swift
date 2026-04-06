import SwiftUI

struct FeedSectionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: FeedViewModel
    let isParentActive: Bool
    @State private var currentPageIndex = 0
    @State private var elapsedInCurrentRange: TimeInterval = 0
    @State private var isViewActive = false
    @State private var previousFeedCount = 0
    @State private var playbackFocusToken = 0
    @State private var selectedProfileDestination: ProfileDestination?
    @State private var isProfileNavigationActive = false

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
        }
        .onAppear {
            isViewActive = true
            previousFeedCount = viewModel.feeds.count
            handleFocusActivated()
        }
        .onDisappear {
            isViewActive = false
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
            if hasAppendedFeed && isPlaybackActive {
                bumpPlaybackFocusToken()
            }
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
                            selectedProfileDestination = makeProfileDestination(from: feed)
                            isProfileNavigationActive = true
                        },
                        onLikeTap: {
                            Task { await viewModel.toggleLike(diaryId: feed.diaryId) }
                        },
                        onStoreTap: {
                            Task { await viewModel.toggleStore(diaryId: feed.diaryId) }
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
                selectedProfileDestination = nil
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
                if let selectedProfileDestination {
                    SocialMyCollectionView(
                        viewModel: makeSocialMyCollectionViewModel(for: selectedProfileDestination)
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

    private func makeSocialMyCollectionViewModel(for destination: ProfileDestination) -> SocialMyCollectionViewModel {
        let initialUser = makeUserModel(from: destination)

        return SocialMyCollectionViewModel(
            initialUser: initialUser,
            onToggleMyPick: { userId, isCurrentlyMyPick in
                let subscribeService = SubscribeService()
                if isCurrentlyMyPick {
                    try await subscribeService.unsubscribe(from: userId)
                } else {
                    try await subscribeService.subscribe(to: userId)
                }
            }
        )
    }

    private func makeUserModel(from destination: ProfileDestination) -> UserModel {
        let username = trimmedString(destination.username, fallback: "킬링파트 사용자")
        let tag = normalizeTag(trimmedString(destination.tag, fallback: "killingpart_user"))
        let profileImageUrl = trimmedString(destination.profileImageUrl, fallback: "")
        return UserModel(
            userId: destination.userId,
            username: username,
            tag: tag,
            identifier: String(destination.userId),
            profileImageUrl: profileImageUrl,
            userRoleType: "USER",
            socialType: "UNKNOWN",
            isMyPick: nil
        )
    }

    private func makeProfileDestination(from feed: DiaryFeedModel) -> ProfileDestination {
        ProfileDestination(
            userId: feed.userId,
            username: feed.username,
            tag: feed.tag,
            profileImageUrl: feed.profileImageUrl
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

    private struct ProfileDestination: Hashable, Identifiable {
        let userId: Int
        let username: String?
        let tag: String?
        let profileImageUrl: String?

        var id: Int { userId }
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
