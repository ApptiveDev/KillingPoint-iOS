import SwiftUI

struct SocialView: View {
    let isRootTabSelected: Bool
    @StateObject private var viewModel = SocialViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @State private var selectedTopTab: SocialTopTab = .friend

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bottomInset = min(geometry.safeAreaInsets.bottom, AppSpacing.xl) + AppSpacing.l

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
                            FriendsSectionView(viewModel: viewModel)
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
    }
}

#Preview {
    SocialView(isRootTabSelected: true)
}
