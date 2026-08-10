import SwiftUI

struct SocialFriendListView: View {
    let users: [SocialListUser]
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let selectedFriendSection: SocialFriendSection
    let bottomContentInset: CGFloat
    let onRetry: () -> Void
    let onUserAppear: (Int) -> Void
    let makeCollectionViewModel: (SocialListUser, Bool?) -> SocialMyCollectionViewModel
    let profileAnalyticsEntryPoint: NotificationAnalyticsEntryPoint?

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.s) {
                if isLoading {
                    ProgressView()
                        .tint(AppColors.primary600)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.xl)
                } else if let errorMessage, users.isEmpty {
                    VStack(spacing: AppSpacing.s) {
                        Text(errorMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Button("다시 시도") {
                            onRetry()
                        }
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xl)
                } else if users.isEmpty {
                    Text("표시할 친구가 없어요.")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.xl)
                } else {
                    LazyVStack(spacing: AppSpacing.s) {
                        ForEach(users) { user in
                            NavigationLink {
                                SocialMyCollectionView(
                                    viewModel: makeCollectionViewModel(for: user),
                                    analyticsEntryPoint: profileAnalyticsEntryPoint
                                )
                                .id(user.userId)
                            } label: {
                                SocialFriendRowView(user: user)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                onUserAppear(user.userId)
                            }
                        }

                        if let lastUserId = users.last?.userId {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    onUserAppear(lastUserId)
                                }
                        }
                    }
                    .padding(.top, AppSpacing.xs)

                    if isLoadingMore {
                        ProgressView()
                            .tint(AppColors.primary600)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, AppSpacing.s)
                    }
                }
            }
            .padding(.bottom, max(bottomContentInset, AppSpacing.l))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func makeCollectionViewModel(for user: SocialListUser) -> SocialMyCollectionViewModel {
        makeCollectionViewModel(
            user,
            selectedFriendSection == .myPick
                ? true
                : (selectedFriendSection == .myFandom ? false : nil)
        )
    }
}
