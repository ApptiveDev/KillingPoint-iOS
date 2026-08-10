import SwiftUI

struct SocialMyCollectionView: View {
    @StateObject private var viewModel: SocialMyCollectionViewModel
    private let analyticsEntryPoint: NotificationAnalyticsEntryPoint?
    @State private var activeConnectionSheet: ConnectionSheetType?
    @State private var activeLikeUsersSheet: LikeUsersSheetContext?
    @State private var pendingNavigationUser: UserModel?
    @State private var selectedNavigationUser: UserModel?
    @State private var isUserCollectionNavigationActive = false
    @State private var likeUsersSearchText = ""
    @State private var hasTrackedProfileView = false

    init(
        viewModel: SocialMyCollectionViewModel,
        analyticsEntryPoint: NotificationAnalyticsEntryPoint? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.analyticsEntryPoint = analyticsEntryPoint
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                profileCard

                if viewModel.isLoadingInitial && viewModel.feeds.isEmpty {
                    ProgressView()
                        .tint(.white.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.xl)
                } else if viewModel.feeds.isEmpty {
                    emptyFeedPlaceholder
                } else {
                    LazyVGrid(columns: feedGridColumns, spacing: AppSpacing.s) {
                        ForEach(viewModel.feeds) { feed in
                            NavigationLink {
                                let diary = viewModel.feeds.first(where: { $0.diaryId == feed.diaryId }) ?? feed
                                SocialMyCollectionDiary(
                                    diaryId: feed.diaryId,
                                    displayTag: viewModel.displayTag,
                                    diary: diary,
                                    makeCollectionViewModel: { user in
                                        viewModel.makeSocialMyCollectionViewModel(for: user)
                                    }
                                )
                            } label: {
                                SocialMyCollectionFeedCard(
                                    feed: feed,
                                    formattedUpdateDate: viewModel.formattedUpdateDate(from: feed.updateDate),
                                    onLikeLongPress: {
                                        likeUsersSearchText = ""
                                        activeLikeUsersSheet = LikeUsersSheetContext(diaryId: feed.diaryId)
                                        Task {
                                            await viewModel.loadLikeUsers(diaryId: feed.diaryId, searchCond: nil)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                guard feed.id == viewModel.feeds.last?.id else { return }
                                Task {
                                    await viewModel.loadMoreFeedsIfNeeded(currentFeedId: feed.id)
                                }
                            }
                        }
                    }
                }

                if viewModel.isLoadingMoreFeeds {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white.opacity(0.88))
                        Spacer()
                    }
                    .padding(.top, AppSpacing.s)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.red.opacity(0.95))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.l)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !hasTrackedProfileView else { return }
            hasTrackedProfileView = true
            NotificationAnalytics.trackProfileViewed(
                entryPoint: analyticsEntryPoint,
                profileUserID: viewModel.user.userId
            )
        }
        .task {
            await viewModel.loadInitialDataIfNeeded()
        }
        .onChange(of: activeConnectionSheet) { sheetType in
            guard sheetType == nil, let pendingNavigationUser else { return }
            self.pendingNavigationUser = nil
            selectedNavigationUser = pendingNavigationUser
            DispatchQueue.main.async {
                isUserCollectionNavigationActive = true
            }
        }
        .onChange(of: activeLikeUsersSheet) { sheetContext in
            if sheetContext == nil {
                viewModel.clearLikeUsersState()
                likeUsersSearchText = ""
                guard let pendingNavigationUser else { return }
                self.pendingNavigationUser = nil
                selectedNavigationUser = pendingNavigationUser
                DispatchQueue.main.async {
                    isUserCollectionNavigationActive = true
                }
            }
        }
        .onChange(of: isUserCollectionNavigationActive) { isActive in
            if !isActive {
                selectedNavigationUser = nil
            }
        }
        .sheet(item: $activeConnectionSheet) { sheetType in
            SocialMyCollectionConnectionListSheet(
                title: sheetType.title,
                users: viewModel.connectionUsers,
                isLoading: viewModel.isLoadingConnections,
                isLoadingMore: viewModel.isLoadingMoreConnections,
                errorMessage: viewModel.connectionErrorMessage,
                emptyMessage: sheetType.emptyMessage,
                onRetry: {
                    Task {
                        await viewModel.refreshActiveConnections()
                    }
                },
                onUserAppear: { userId in
                    Task {
                        await viewModel.loadMoreConnectionsIfNeeded(currentUserId: userId)
                    }
                },
                onUserTap: { user in
                    pendingNavigationUser = UserModel(from: user)
                    activeConnectionSheet = nil
                }
            )
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
                    pendingNavigationUser = user
                    activeLikeUsersSheet = nil
                }
            )
        }
        .background(userCollectionNavigationLink)
    }

    private var feedGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s)
        ]
    }

    private var profileCard: some View {
        SocialMyCollectionProfileCard(
            displayName: viewModel.displayName,
            displayTag: viewModel.displayTag,
            profileImageURL: viewModel.profileImageURL,
            killingPartStatText: viewModel.killingPartStatText,
            fanStatText: viewModel.fanStatText,
            pickStatText: viewModel.pickStatText,
            isMyPick: viewModel.isMyPick,
            onFanStatTap: {
                presentConnectionSheet(.fandom)
            },
            onPickStatTap: {
                presentConnectionSheet(.picks)
            },
            onPickToggleTap: {
                Task {
                    await viewModel.toggleMyPick()
                }
            }
        )
    }

    private var emptyFeedPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay {
                Text("아직 작성한 피드가 없어요.")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private var userCollectionNavigationLink: some View {
        NavigationLink(
            isActive: $isUserCollectionNavigationActive,
            destination: {
                if let selectedNavigationUser {
                    SocialMyCollectionView(
                        viewModel: viewModel.makeSocialMyCollectionViewModel(for: selectedNavigationUser)
                    )
                    .id(selectedNavigationUser.userId)
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

    private func presentConnectionSheet(_ sheetType: ConnectionSheetType) {
        activeConnectionSheet = sheetType
        Task {
            await viewModel.loadConnections(type: sheetType.connectionType)
        }
    }

    private var normalizedLikeUsersSearchCond: String? {
        let trimmed = likeUsersSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private enum ConnectionSheetType: String, Identifiable {
        case picks
        case fandom

        var id: String { rawValue }

        var title: String {
            switch self {
            case .picks:
                return "PICKS"
            case .fandom:
                return "팬덤"
            }
        }

        var emptyMessage: String {
            switch self {
            case .picks:
                return "표시할 PICKS가 없어요."
            case .fandom:
                return "표시할 팬덤이 없어요."
            }
        }

        var connectionType: SocialMyCollectionViewModel.ConnectionType {
            switch self {
            case .picks:
                return .picks
            case .fandom:
                return .fandom
            }
        }
    }

    private struct LikeUsersSheetContext: Identifiable, Equatable {
        let diaryId: Int
        var id: Int { diaryId }
    }
}

private struct SocialMyCollectionConnectionListSheet: View {
    let title: String
    let users: [SubscribeUserModel]
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let emptyMessage: String
    let onRetry: () -> Void
    let onUserAppear: (Int) -> Void
    let onUserTap: (SubscribeUserModel) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text(title)
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isLoading && users.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.primary600)
                    Spacer()
                }
                .padding(.top, AppSpacing.xl)
            } else if let errorMessage, users.isEmpty {
                VStack(spacing: AppSpacing.s) {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button("다시 시도") {
                        onRetry()
                    }
                    .font(AppFont.paperlogy5Medium(size: 13))
                    .foregroundStyle(AppColors.primary600)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.xl)
            } else if users.isEmpty {
                Text(emptyMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, AppSpacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.s) {
                        ForEach(users) { user in
                            Button {
                                onUserTap(user)
                            } label: {
                                SocialFriendRowView(user: .subscribed(user))
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                onUserAppear(user.userId)
                            }
                        }

                        if isLoadingMore {
                            ProgressView()
                                .tint(AppColors.primary600)
                                .padding(.top, AppSpacing.s)
                        }
                    }
                    .padding(.bottom, AppSpacing.m)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.m)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}
