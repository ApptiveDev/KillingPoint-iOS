import SwiftUI

struct SocialView: View {
    let isRootTabSelected: Bool
    @ObservedObject var viewModel: SocialViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    @State private var selectedTopTab: SocialTopTab = .feed
    @State private var isNotificationListActive = false
    @State private var friendSearchText: String

    init(
        isRootTabSelected: Bool,
        viewModel: SocialViewModel,
        feedViewModel: FeedViewModel
    ) {
        self.isRootTabSelected = isRootTabSelected
        self.viewModel = viewModel
        self.feedViewModel = feedViewModel
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

                                    if viewModel.notificationListViewModel.hasUnreadAlarms {
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
            async let refreshSocialList: Void = viewModel.refreshDefaultLists()
            async let refreshAlarmList: Void = viewModel.notificationListViewModel.refreshAlarms()
            _ = await (refreshSocialList, refreshAlarmList)
        }
        .onChange(of: viewModel.notificationListViewModel.pendingExternalRoute) { pendingRoute in
            guard let pendingRoute else { return }

            switch pendingRoute {
            case .socialFriends:
                print("[PushRoute] external route -> Social Friends Section")
                selectedTopTab = .friend
                isNotificationListActive = false
            }

            viewModel.notificationListViewModel.clearPendingExternalRoute()
        }
        .alert(
            "알림 이동 실패",
            isPresented: routingErrorPresentedBinding
        ) {
            Button("확인", role: .cancel) {
                viewModel.notificationListViewModel.clearRoutingError()
            }
        } message: {
            Text(viewModel.notificationListViewModel.routingErrorMessage ?? "알림을 열 수 없어요.")
        }
    }

    private var navigationLinks: some View {
        ZStack {
            notificationNavigationLink
            alarmRouteNavigationLinks
        }
    }

    private var notificationNavigationLink: some View {
        NavigationLink(
            isActive: $isNotificationListActive,
            destination: {
                NotificationListView(viewModel: viewModel.notificationListViewModel)
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
                    if let destination = viewModel.notificationListViewModel.activeMyDiaryDestination {
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
                    if let destination = viewModel.notificationListViewModel.activeSocialDiaryDestination {
                        SocialMyCollectionDiary(
                            diaryId: destination.diary.diaryId,
                            displayTag: destination.displayTag,
                            diary: destination.diary,
                            makeCollectionViewModel: { user in
                                viewModel.notificationListViewModel.makeSocialMyCollectionViewModel(for: user)
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
                    if let destination = viewModel.notificationListViewModel.activeSocialCollectionDestination {
                        SocialMyCollectionView(
                            viewModel: viewModel.notificationListViewModel.makeSocialMyCollectionViewModel(
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
                viewModel.notificationListViewModel.activeMyDiaryDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                viewModel.notificationListViewModel.clearActiveMyDiaryDestination()
            }
        )
    }

    private var socialDiaryNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.notificationListViewModel.activeSocialDiaryDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                viewModel.notificationListViewModel.clearActiveSocialDiaryDestination()
            }
        )
    }

    private var socialCollectionNavigationBinding: Binding<Bool> {
        Binding(
            get: {
                viewModel.notificationListViewModel.activeSocialCollectionDestination != nil
            },
            set: { isActive in
                guard !isActive else { return }
                viewModel.notificationListViewModel.clearActiveSocialCollectionDestination()
            }
        )
    }

    private var routingErrorPresentedBinding: Binding<Bool> {
        Binding(
            get: {
                !isNotificationListActive && viewModel.notificationListViewModel.routingErrorMessage != nil
            },
            set: { isPresented in
                guard !isPresented else { return }
                viewModel.notificationListViewModel.clearRoutingError()
            }
        )
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
