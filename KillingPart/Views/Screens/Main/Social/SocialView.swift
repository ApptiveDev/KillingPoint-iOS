import SwiftUI

struct SocialView: View {
    let isRootTabSelected: Bool
    @ObservedObject var viewModel: SocialViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    @State private var selectedTopTab: SocialTopTab = .feed
    @State private var isNotificationListActive = false

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

                                    if viewModel.hasUnreadAlarms {
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
                                bottomContentInset: friendsBottomContentInset
                            )
                        } else {
                            FeedSectionView(
                                viewModel: feedViewModel,
                                isParentActive: isRootTabSelected && selectedTopTab == .feed,
                                makeCollectionViewModel: { user in
                                    viewModel.makeSocialMyCollectionViewModel(for: user)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, bottomInset)
                    .background(notificationNavigationLink)
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
            async let refreshAlarmList: Void = viewModel.refreshAlarms()
            _ = await (refreshSocialList, refreshAlarmList)
        }
    }

    private var notificationNavigationLink: some View {
        NavigationLink(
            isActive: $isNotificationListActive,
            destination: {
                NotificationListView(viewModel: viewModel)
            },
            label: {
                EmptyView()
            }
        )
        .hidden()
    }
}

#Preview {
    SocialView(
        isRootTabSelected: true,
        viewModel: SocialViewModel(),
        feedViewModel: FeedViewModel()
    )
}
