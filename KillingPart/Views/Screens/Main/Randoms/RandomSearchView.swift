import SwiftUI

struct RandomSearchView: View {
    let isRootTabSelected: Bool
    let refreshTrigger: Int
    @StateObject private var socialViewModel = SocialViewModel()
    @StateObject private var feedViewModel = FeedViewModel(feedSource: .random)
    @State private var isRefreshingFromTabEvent = false
    @State private var refreshErrorMessage: String?
    @State private var lastTabEventRefreshAt: Date = .distantPast
    @State private var exploreSwipeCountInSession = 0
    private let tabEventRefreshDebounceInterval: TimeInterval = 3

    var body: some View {
        NavigationStack {
            ZStack {
                KillingPartBackgroundView()

                FeedSectionView(
                    viewModel: feedViewModel,
                    isParentActive: isRootTabSelected,
                    makeCollectionViewModel: { user in
                        socialViewModel.makeSocialMyCollectionViewModel(
                            for: resolvedCollectionUser(from: user)
                        )
                    },
                    onPageChanged: { oldIndex, newIndex, diaryId in
                        exploreSwipeCountInSession += 1
                        AmplitudeClient.shared.track(
                            eventType: "explore_feed_card_viewed",
                            properties: [
                                "from_index": oldIndex,
                                "to_index": newIndex,
                                "swipe_count_in_session": exploreSwipeCountInSession,
                                "diary_id": diaryId
                            ]
                        )
                    }
                )
                .padding(.top, AppSpacing.l)
                .padding(.horizontal, AppSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if isRefreshingFromTabEvent {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()

                    ProgressView()
                        .tint(AppColors.primary600)
                        .padding(AppSpacing.l)
                        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            async let loadFeedTask: Void = feedViewModel.loadInitialDataIfNeeded()
            async let loadSocialTask: Void = socialViewModel.loadInitialDataIfNeeded()
            _ = await (loadFeedTask, loadSocialTask)
        }
        .onChange(of: refreshTrigger) { _ in
            guard isRootTabSelected else { return }
            refreshByTabEvent()
        }
        .alert(
            "탐색 새로고침 실패",
            isPresented: refreshErrorPresentedBinding
        ) {
            Button("확인", role: .cancel) {
                refreshErrorMessage = nil
            }
        } message: {
            Text(refreshErrorMessage ?? "새로고침에 실패했어요.")
        }
    }

    private func resolvedCollectionUser(from user: UserModel) -> UserModel {
        guard user.isMyPick == nil else { return user }

        if let matchedMyPickUser = socialViewModel.myPickUsers.first(where: { $0.userId == user.userId }) {
            return UserModel(from: matchedMyPickUser, isMyPick: true)
        }

        if let matchedMyFandomUser = socialViewModel.myFandomUsers.first(where: { $0.userId == user.userId }) {
            return UserModel(from: matchedMyFandomUser, isMyPick: false)
        }

        return user
    }

    private var refreshErrorPresentedBinding: Binding<Bool> {
        Binding(
            get: { refreshErrorMessage != nil },
            set: { isPresented in
                guard !isPresented else { return }
                refreshErrorMessage = nil
            }
        )
    }

    private func refreshByTabEvent() {
        let now = Date()
        guard now.timeIntervalSince(lastTabEventRefreshAt) >= tabEventRefreshDebounceInterval else { return }
        guard !isRefreshingFromTabEvent else { return }
        lastTabEventRefreshAt = now
        isRefreshingFromTabEvent = true
        refreshErrorMessage = nil

        Task { @MainActor in
            async let refreshFeedTask: Void = feedViewModel.refresh(showInitialLoading: false)
            async let refreshSocialTask: Void = socialViewModel.refreshDefaultLists()
            _ = await (refreshFeedTask, refreshSocialTask)

            if let message = resolvedRefreshErrorMessage() {
                refreshErrorMessage = message
            }
            isRefreshingFromTabEvent = false
        }
    }

    private func resolvedRefreshErrorMessage() -> String? {
        if let feedErrorMessage = feedViewModel.errorMessage {
            return feedErrorMessage
        }
        if let socialErrorMessage = socialViewModel.errorMessage {
            return socialErrorMessage
        }
        return nil
    }
}

#Preview {
    RandomSearchView(isRootTabSelected: true, refreshTrigger: 0)
}
