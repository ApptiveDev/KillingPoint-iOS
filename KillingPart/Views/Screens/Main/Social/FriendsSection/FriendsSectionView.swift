import SwiftUI

struct FriendsSectionView: View {
    @ObservedObject var viewModel: SocialViewModel
    @State private var selectedFriendSection: SocialFriendSection = .myPick
    @State private var searchText = ""

    var body: some View {
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
                .frame(maxWidth: .infinity, alignment: .leading)
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
        .onChange(of: searchText) { query in
            Task {
                await viewModel.searchUsers(with: query)
            }
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
