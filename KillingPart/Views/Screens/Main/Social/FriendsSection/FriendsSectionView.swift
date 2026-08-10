import SwiftUI

struct FriendsSectionView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Binding var searchText: String
    let bottomContentInset: CGFloat
    @Binding var requestedFriendSection: SocialFriendSection?
    @Binding var profileAnalyticsEntryPoint: NotificationAnalyticsEntryPoint?
    @State private var selectedFriendSection: SocialFriendSection = .myPick

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
                bottomContentInset: bottomContentInset,
                onRetry: {
                    Task { await viewModel.refreshCurrentList() }
                },
                onUserAppear: { userId in
                    guard currentSectionUsers.last?.userId == userId else { return }
                    guard !isCurrentSectionLoading, !isCurrentSectionLoadingMore else { return }

                    Task {
                        await viewModel.loadMoreCurrentSectionIfNeeded(
                            currentUserId: userId,
                            isMyPickSection: isCurrentSectionMyPick
                        )
                    }
                },
                makeCollectionViewModel: { user, fallbackIsMyPick in
                    viewModel.makeSocialMyCollectionViewModel(for: user, fallbackIsMyPick: fallbackIsMyPick)
                },
                profileAnalyticsEntryPoint: profileAnalyticsEntryPoint
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onChange(of: searchText) { query in
            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                profileAnalyticsEntryPoint = nil
            }
            Task {
                await viewModel.searchUsers(with: query)
            }
        }
        .onChange(of: requestedFriendSection) { section in
            guard let section else { return }
            selectedFriendSection = section
            requestedFriendSection = nil
        }
        .onAppear {
            if let requestedFriendSection {
                selectedFriendSection = requestedFriendSection
                self.requestedFriendSection = nil
            }
        }
        .onChange(of: selectedFriendSection) { section in
            if section != .myFandom {
                profileAnalyticsEntryPoint = nil
            }
        }
    }

    private var currentSectionUsers: [SocialListUser] {
        viewModel.users(for: isCurrentSectionMyPick)
    }

    private var isCurrentSectionLoading: Bool {
        viewModel.isLoading(for: isCurrentSectionMyPick)
    }

    private var isCurrentSectionLoadingMore: Bool {
        viewModel.isLoadingMore(for: isCurrentSectionMyPick)
    }

    private var isCurrentSectionMyPick: Bool {
        selectedFriendSection == .myPick
    }
}
