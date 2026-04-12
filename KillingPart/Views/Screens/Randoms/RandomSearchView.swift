import SwiftUI

struct RandomSearchView: View {
    let isRootTabSelected: Bool
    @StateObject private var socialViewModel = SocialViewModel()
    @StateObject private var feedViewModel = FeedViewModel(feedSource: .random)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bottomInset = min(geometry.safeAreaInsets.bottom, AppSpacing.xl) + AppSpacing.l
                let extraBottomInset = AppSpacing.m

                ZStack {
                    Image("my_background")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .ignoresSafeArea()

                    VStack(spacing: 0) {
                        FeedSectionView(
                            viewModel: feedViewModel,
                            isParentActive: isRootTabSelected,
                            makeCollectionViewModel: { user in
                                socialViewModel.makeSocialMyCollectionViewModel(for: user)
                            }
                        )
                    }
                    .padding(.top, AppSpacing.l)
                    .padding(.horizontal, AppSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.bottom, bottomInset + extraBottomInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .padding(.bottom, bottomInset)
            }
        }
        .task {
            await feedViewModel.loadInitialDataIfNeeded()
        }
    }
}

#Preview {
    RandomSearchView(isRootTabSelected: true)
}
