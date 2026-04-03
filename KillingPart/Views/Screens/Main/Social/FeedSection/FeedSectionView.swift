import SwiftUI

struct FeedSectionView: View {
    @ObservedObject var viewModel: FeedViewModel
    @State private var currentPageIndex = 0

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = max(geometry.safeAreaInsets.bottom, AppSpacing.s) + AppSpacing.s
            Group {
                if viewModel.isLoadingInitial {
                    ProgressView()
                        .tint(AppColors.primary600)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, AppSpacing.xl)
                } else if let errorMessage = viewModel.errorMessage, viewModel.feeds.isEmpty {
                    VStack(spacing: AppSpacing.s) {
                        Text(errorMessage)
                            .font(AppFont.paperlogy4Regular(size: 13))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        Button("다시 시도") {
                            Task { await viewModel.refresh() }
                        }
                        .font(AppFont.paperlogy5Medium(size: 13))
                        .foregroundStyle(AppColors.primary600)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, AppSpacing.xl)
                } else if viewModel.feeds.isEmpty {
                    Text("표시할 피드가 없어요.")
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, AppSpacing.xl)
                } else {
                    feedPager
                }
            }
            .padding(.bottom, bottomInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var feedPager: some View {
        VStack(spacing: AppSpacing.s) {
            TabView(selection: $currentPageIndex) {
                ForEach(Array(viewModel.feeds.enumerated()), id: \.element.id) { index, feed in
                    let isActive = index == currentPageIndex

                    SocialFeedPageCardView(
                        feed: feed,
                        isVideoPlaying: isActive
                    )
                    .tag(index)
                    .padding(.top, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.xs)
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentDiaryId: feed.diaryId) }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(AppColors.primary600)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
