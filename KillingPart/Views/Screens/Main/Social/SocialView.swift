import SwiftUI

struct SocialView: View {
    let isRootTabSelected: Bool
    @ObservedObject var viewModel: SocialViewModel
    @ObservedObject var feedViewModel: FeedViewModel
    @State private var selectedTopTab: SocialTopTab = .feed

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
                        SocialTopToggleTabsView(selectedTopTab: $selectedTopTab)

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
            await viewModel.refreshDefaultLists()
        }
    }
}

#Preview {
    SocialView(
        isRootTabSelected: true,
        viewModel: SocialViewModel(),
        feedViewModel: FeedViewModel()
    )
}
