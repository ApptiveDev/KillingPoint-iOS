import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel = SocialViewModel()
    @State private var selectedTopTab: SocialTopTab = .friend
    @State private var selectedFriendSection: SocialFriendSection = .myPick
    @State private var searchText = ""

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
                            friendSection
                        } else {
                            SocialFeedPlaceholderView()
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
            guard selectedTopTab == .friend else { return }
            await viewModel.loadInitialDataIfNeeded()
        }
        .onChange(of: searchText) { query in
            Task {
                await viewModel.searchUsers(with: query)
            }
        }
    }

    private var friendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            SocialSearchBarView(searchText: $searchText)
            if viewModel.isSearching {
                SocialSearchedResultHeaderView(totalCount: viewModel.searchedUserTotalCount)
            } else {
                SocialFriendToggleTabsView(
                    selectedFriendSection: $selectedFriendSection,
                    myPickCount: viewModel.totalCount(for: true),
                    myFandomCount: viewModel.totalCount(for: false)
                )
            }
            SocialFriendListView(
                users: currentSectionUsers,
                isLoading: isCurrentSectionLoading,
                isLoadingMore: isCurrentSectionLoadingMore,
                errorMessage: viewModel.errorMessage,
                selectedFriendSection: selectedFriendSection,
                onRetry: {
                    Task { await viewModel.refreshCurrentList() }
                },
                onUserAppear: { userId in
                    Task {
                        await viewModel.loadMoreCurrentSectionIfNeeded(
                            currentUserId: userId,
                            isMyPickSection: selectedFriendSection == .myPick
                        )
                    }
                },
                makeCollectionViewModel: { user, fallbackIsMyPick in
                    viewModel.makeSocialMyCollectionViewModel(for: user, fallbackIsMyPick: fallbackIsMyPick)
                }
            )
        }
    }

    private var currentSectionUsers: [SocialListUser] {
        viewModel.users(for: selectedFriendSection == .myPick)
    }

    private var isCurrentSectionLoading: Bool {
        viewModel.isLoading(for: selectedFriendSection == .myPick)
    }

    private var isCurrentSectionLoadingMore: Bool {
        viewModel.isLoadingMore(for: selectedFriendSection == .myPick)
    }
}

#Preview {
    SocialView()
}
