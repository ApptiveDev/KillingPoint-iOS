import SwiftUI

struct RandomSearchView: View {
    let isRootTabSelected: Bool
    @StateObject private var socialViewModel = SocialViewModel()
    @StateObject private var feedViewModel = FeedViewModel(feedSource: .random)

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let bottomInset = min(geometry.safeAreaInsets.bottom, AppSpacing.xl) + AppSpacing.xl
                let extraBottomInset = AppSpacing.xl

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
                                socialViewModel.makeSocialMyCollectionViewModel(
                                    for: resolvedCollectionUser(from: user)
                                )
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
            async let loadFeedTask: Void = feedViewModel.loadInitialDataIfNeeded()
            async let loadSocialTask: Void = socialViewModel.loadInitialDataIfNeeded()
            _ = await (loadFeedTask, loadSocialTask)
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
}

#Preview {
    RandomSearchView(isRootTabSelected: true)
}
