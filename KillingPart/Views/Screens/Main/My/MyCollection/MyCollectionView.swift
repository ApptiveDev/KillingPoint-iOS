import SwiftUI

struct MyCollectionView: View {
    let onSessionEnded: () -> Void

    @StateObject private var viewModel: MyCollectionViewModel
    @StateObject private var storesViewModel: MyCollectionStoresViewModel
    @StateObject private var profileSettingViewModel: ProfileSettingViewModel
    @State private var isSettingsNavigationPresented = false
    @State private var selectedKillingPartSection: MyCollectionKillingPartSection = .myKillingPart
    @State private var activeConnectionSheet: ConnectionSheetType?
    @State private var activeLikeUsersSheet: LikeUsersSheetContext?
    @State private var pendingNavigationUser: UserModel?
    @State private var selectedNavigationUser: UserModel?
    @State private var isUserCollectionNavigationActive = false
    @State private var likeUsersSearchText = ""

    init(
        onSessionEnded: @escaping () -> Void,
        authenticationService: AuthenticationServicing = AuthenticationService(),
        userService: UserServicing = UserService(),
        diaryService: DiaryServicing = DiaryService(),
        subscribeService: SubscribeServicing = SubscribeService()
    ) {
        self.onSessionEnded = onSessionEnded
        _viewModel = StateObject(
            wrappedValue: MyCollectionViewModel(
                authenticationService: authenticationService,
                userService: userService,
                diaryService: diaryService,
                subscribeService: subscribeService
            )
        )
        _profileSettingViewModel = StateObject(
            wrappedValue: ProfileSettingViewModel(userService: userService)
        )
        _storesViewModel = StateObject(
            wrappedValue: MyCollectionStoresViewModel(diaryService: diaryService)
        )
    }

    var body: some View {
        myFeedSection
        .onAppear {
            Task {
                async let myKillingPartLoad: Void = viewModel.loadInitialDataIfNeeded()
                if selectedKillingPartSection == .storeKillingPart {
                    async let storedKillingPartLoad: Void = storesViewModel.loadInitialDataIfNeeded()
                    _ = await (myKillingPartLoad, storedKillingPartLoad)
                } else {
                    _ = await myKillingPartLoad
                }
            }
        }
        .onChange(of: viewModel.user?.identifier) { _ in
            profileSettingViewModel.syncUser(viewModel.user)
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryCreated)) { _ in
            Task {
                async let myKillingPartRefresh: Void = viewModel.refetchCollectionDataOnFocus()
                async let storedKillingPartRefresh: Void = storesViewModel.refetchStoredDiariesOnFocus()
                _ = await (myKillingPartRefresh, storedKillingPartRefresh)
            }
        }
        .navigationDestination(for: MyCollectionDiaryRoute.self) { route in
            let diary = viewModel.myFeeds.first(where: { $0.diaryId == route.diaryId }) ?? route.initialDiary

            MyCollectionDiary(
                diaryId: route.diaryId,
                displayTag: viewModel.displayTag,
                diary: diary
            ) { updatedDiary in
                viewModel.applyUpdatedFeed(updatedDiary)
            } onDiaryDeleted: { changedDiaryId in
                viewModel.removeMyFeedLocally(diaryId: changedDiaryId)
            }
        }
        .navigationDestination(for: StoreKillingPartDetailRoute.self) { route in
            let diary = storesViewModel.storedDiaries.first(where: { $0.diaryId == route.diaryId }) ?? route.initialDiary

            StoreKillingPartDetail(
                diaryId: route.diaryId,
                diary: diary
            ) { removedDiaryId in
                storesViewModel.removeStoredDiaryLocally(diaryId: removedDiaryId)
            }
        }
        .navigationDestination(isPresented: $isSettingsNavigationPresented) {
            SettingsView(
                viewModel: profileSettingViewModel,
                onUserUpdated: { updatedUser in
                    viewModel.applyUpdatedUser(updatedUser)
                    profileSettingViewModel.syncUser(updatedUser)
                },
                onLogoutTap: {
                    guard !viewModel.isProcessing, !profileSettingViewModel.isProcessing else { return }
                    viewModel.logout(onSuccess: onSessionEnded)
                },
                onWithdrawalTap: {
                    guard !viewModel.isProcessing, !profileSettingViewModel.isProcessing else { return }
                    viewModel.deleteMyAccount(onSuccess: onSessionEnded)
                }
            )
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
            MyCollectionConnectionListSheet(
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

    private var myFeedSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                profileCard

                killingPartSectionToggle

                if selectedKillingPartSection == .myKillingPart {
                    MyCollectionMyKillingPartSectionView(
                        feeds: viewModel.myFeeds,
                        isLoadingMoreFeeds: viewModel.isLoadingMoreFeeds,
                        errorMessage: viewModel.errorMessage,
                        onLikeLongPress: { feed in
                            likeUsersSearchText = ""
                            activeLikeUsersSheet = LikeUsersSheetContext(diaryId: feed.diaryId)
                            Task {
                                await viewModel.loadLikeUsers(diaryId: feed.diaryId, searchCond: nil)
                            }
                        },
                        onFeedAppear: { feed in
                            guard feed.id == viewModel.myFeeds.last?.id else { return }
                            Task {
                                await viewModel.loadMoreMyFeedsFromBottomIfNeeded()
                            }
                        },
                        onBottomTriggerAppear: {
                            Task {
                                await viewModel.loadMoreMyFeedsFromBottomIfNeeded()
                            }
                        }
                    )
                } else {
                    MyCollectionStoreKillingPartSectionView(
                        diaries: storesViewModel.storedDiaries,
                        isLoadingInitial: storesViewModel.isLoadingInitial,
                        isLoadingMore: storesViewModel.isLoadingMore,
                        errorMessage: storesViewModel.errorMessage,
                        onDiaryAppear: { diary in
                            guard diary.id == storesViewModel.storedDiaries.last?.id else { return }
                            Task {
                                await storesViewModel.loadMoreStoredDiariesIfNeeded(currentDiaryId: diary.diaryId)
                            }
                        },
                        onBottomTriggerAppear: {
                            Task {
                                await storesViewModel.loadMoreStoredDiariesFromBottomIfNeeded()
                            }
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.l)
        }
        .onChange(of: selectedKillingPartSection) { section in
            guard section == .storeKillingPart else { return }
            Task {
                await storesViewModel.loadInitialDataIfNeeded()
            }
        }
    }

    private var killingPartSectionToggle: some View {
        HStack(spacing: 0) {
            sectionToggleButton(for: .myKillingPart)
            sectionToggleButton(for: .storeKillingPart)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionToggleButton(for section: MyCollectionKillingPartSection) -> some View {
        let isActive = selectedKillingPartSection == section

        return Button {
            guard selectedKillingPartSection != section else { return }
            selectedKillingPartSection = section
        } label: {
            VStack(spacing: 6) {
                Text(section.title)
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.white)
                    .opacity(isActive ? 1 : 0.45)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(isActive ? 1 : 0.24))
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var profileCard: some View {
        MyCollectionProfileCard(
            displayName: viewModel.displayName,
            displayTag: viewModel.displayTag,
            profileImageURL: viewModel.profileImageURL,
            killingPartStatText: viewModel.killingPartStatText,
            fanStatText: viewModel.fanStatText,
            pickStatText: viewModel.pickStatText,
            onFanStatTap: {
                presentConnectionSheet(.fandom)
            },
            onPickStatTap: {
                presentConnectionSheet(.picks)
            }
        ) {
            profileSettingViewModel.syncUser(viewModel.user)
            isSettingsNavigationPresented = true
        }
    }

    private var normalizedLikeUsersSearchCond: String? {
        let trimmed = likeUsersSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

        var connectionType: MyCollectionViewModel.ConnectionType {
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

private struct MyCollectionConnectionListSheet: View {
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

struct MyCollectionDiaryRoute: Hashable {
    let diaryId: Int
    let initialDiary: DiaryFeedModel

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.diaryId == rhs.diaryId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(diaryId)
    }
}

private enum MyCollectionKillingPartSection: Equatable {
    case myKillingPart
    case storeKillingPart

    var title: String {
        switch self {
        case .myKillingPart:
            return "내 킬링파트"
        case .storeKillingPart:
            return "보관된 킬링파트"
        }
    }
}
