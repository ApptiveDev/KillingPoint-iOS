import SwiftUI

struct SocialView: View {
    let isRootTabSelected: Bool
    @ObservedObject var viewModel: SocialViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    let deepLinkRequest: DeepLinkRequest?
    let onDeepLinkRequestConsumed: (DeepLinkRequest) -> Void
    @ObservedObject private var notificationListViewModel: NotificationListViewModel
    @State private var selectedTopTab: SocialTopTab = .feed
    @State private var isNotificationListActive = false
    @State private var friendSearchText: String
    @State private var handledDeepLinkRequestID: UUID?

    init(
        isRootTabSelected: Bool,
        viewModel: SocialViewModel,
        feedViewModel: FeedViewModel,
        deepLinkRequest: DeepLinkRequest? = nil,
        onDeepLinkRequestConsumed: @escaping (DeepLinkRequest) -> Void = { _ in }
    ) {
        self.isRootTabSelected = isRootTabSelected
        self.viewModel = viewModel
        self.feedViewModel = feedViewModel
        self.deepLinkRequest = deepLinkRequest
        self.onDeepLinkRequestConsumed = onDeepLinkRequestConsumed
        _notificationListViewModel = ObservedObject(wrappedValue: viewModel.notificationListViewModel)
        _friendSearchText = State(initialValue: viewModel.currentSearchQuery)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bottomInset = min(geometry.safeAreaInsets.bottom, AppSpacing.xl) + AppSpacing.l
                let friendsBottomContentInset = max(geometry.safeAreaInsets.bottom, AppSpacing.m) + AppSpacing.xl

                ZStack {
                    Image("my_background")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()

                    VStack(spacing: AppSpacing.m) {
                        HStack(spacing: AppSpacing.s) {
                            SocialTopToggleTabsView(selectedTopTab: $selectedTopTab)
                                .frame(maxWidth: .infinity)

                            Button {
                                isNotificationListActive = true
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.kpPrimary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.1))
                                        )

                                    if notificationListViewModel.hasUnreadAlarms {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 9, height: 9)
                                            .offset(x: -4, y: 4)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if selectedTopTab == .friend {
                            FriendsSectionView(
                                viewModel: viewModel,
                                searchText: $friendSearchText,
                                bottomContentInset: friendsBottomContentInset
                            )
                        } else {
                            FeedSectionView(
                                viewModel: feedViewModel,
                                isParentActive: isRootTabSelected && selectedTopTab == .feed,
                                makeCollectionViewModel: { user in
                                    viewModel.makeSocialMyCollectionViewModel(
                                        for: resolvedCollectionUser(from: user)
                                    )
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, bottomInset)
                    .background(navigationLinks)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .padding(.bottom, bottomInset)
            }
        }
        .task(id: selectedTopTab) {
            switch selectedTopTab {
            case .friend:
                await viewModel.loadInitialDataIfNeeded()
            case .feed:
                await feedViewModel.loadInitialDataIfNeeded()
            }
        }
        .task(id: isRootTabSelected) {
            guard isRootTabSelected else { return }
            await handleDeepLinkRequestIfNeeded()
            async let refreshSocialList: Void = viewModel.refreshDefaultLists()
            async let refreshAlarmList: Void = notificationListViewModel.refreshAlarms()
            _ = await (refreshSocialList, refreshAlarmList)
        }
        .task(id: deepLinkRequest?.id) {
            await handleDeepLinkRequestIfNeeded()
        }
        .onChange(of: notificationListViewModel.pendingExternalRoute) { pendingRoute in
            guard let pendingRoute else { return }

            switch pendingRoute {
            case .socialFriends:
                print("[PushRoute] external route -> Social Friends Section")
                selectedTopTab = .friend
                isNotificationListActive = false
            }

            notificationListViewModel.clearPendingExternalRoute()
        }
        .alert(
            "이동 실패",
            isPresented: routingErrorPresentedBinding
        ) {
            Button("확인", role: .cancel) {
                notificationListViewModel.clearRoutingError()
            }
        } message: {
            Text(notificationListViewModel.routingErrorMessage ?? "알림을 열 수 없어요.")
        }
    }

    private var navigationLinks: some View {
        ZStack {
            notificationNavigationLink

            // NotificationListView owns these routes while it is on the stack.
            if !isNotificationListActive {
                alarmRouteNavigationLinks
            }
        }
    }

    private var notificationNavigationLink: some View {
        NavigationLink(
            isActive: $isNotificationListActive,
            destination: {
                NotificationListView(viewModel: notificationListViewModel)
            },
            label: {
                EmptyView()
            }
        )
        .hidden()
    }

    private var alarmRouteNavigationLinks: some View {
        ZStack {
            NavigationLink(
                isActive: myDiaryNavigationBinding,
                destination: {
                    if let destination = notificationListViewModel.activeMyDiaryDestination {
                        MyCollectionDiary(
                            diaryId: destination.diary.diaryId,
                            displayTag: destination.displayTag,
                            diary: destination.diary
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

            NavigationLink(
                isActive: socialDiaryNavigationBinding,
                destination: {
                    if let destination = notificationListViewModel.activeSocialDiaryDestination {
                        SocialMyCollectionDiary(
                            diaryId: destination.diary.diaryId,
                            displayTag: destination.displayTag,
                            diary: destination.diary,
                            makeCollectionViewModel: { user in
                                notificationListViewModel.makeSocialMyCollectionViewModel(for: user)
                            }
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

            NavigationLink(
                isActive: socialCollectionNavigationBinding,
                destination: {
                    if let destination = notificationListViewModel.activeSocialCollectionDestination {
                        SocialMyCollectionView(
                            viewModel: notificationListViewModel.makeSocialMyCollectionViewModel(
                                for: destination.user,
                                initialUserFeedsResponse: destination.initialUserFeedsResponse
                            )
                        )
                        .id(destination.user.userId)
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
    }

    private var myDiaryNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                notificationListViewModel.activeMyDiaryDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                notificationListViewModel.clearActiveMyDiaryDestination()
            }
        )
    }

    private var socialDiaryNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                notificationListViewModel.activeSocialDiaryDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                notificationListViewModel.clearActiveSocialDiaryDestination()
            }
        )
    }

    private var socialCollectionNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                notificationListViewModel.activeSocialCollectionDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                notificationListViewModel.clearActiveSocialCollectionDestination()
            }
        )
    }

    private var routingErrorPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                !isNotificationListActive && notificationListViewModel.routingErrorMessage != nil
            },
            set: { isPresented in
                guard !isPresented else { return }
                notificationListViewModel.clearRoutingError()
            }
        )
    }

    @MainActor
    private func handleDeepLinkRequestIfNeeded() async {
        guard isRootTabSelected else { return }
        guard let deepLinkRequest else { return }
        guard handledDeepLinkRequestID != deepLinkRequest.id else { return }

        handledDeepLinkRequestID = deepLinkRequest.id
        selectedTopTab = .feed
        isNotificationListActive = false

        switch deepLinkRequest.route {
        case .socialDiary(let diaryId):
            await notificationListViewModel.handleUniversalLinkDiaryRoute(diaryId: diaryId)
        }

        onDeepLinkRequestConsumed(deepLinkRequest)
    }

    private func resolvedCollectionUser(from user: UserModel) -> UserModel {
        guard user.isMyPick == nil else { return user }

        if let matchedMyPickUser = viewModel.myPickUsers.first(where: { $0.userId == user.userId }) {
            return UserModel(from: matchedMyPickUser, isMyPick: true)
        }

        if let matchedMyFandomUser = viewModel.myFandomUsers.first(where: { $0.userId == user.userId }) {
            return UserModel(from: matchedMyFandomUser, isMyPick: false)
        }

        return user
    }
}

#Preview {
    SocialView(
        isRootTabSelected: true,
        viewModel: SocialViewModel(),
        feedViewModel: FeedViewModel()
    )
}
