import SwiftUI

struct FeedSectionView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: FeedViewModel
    @State private var currentPageIndex = 0
    @State private var elapsedInCurrentRange: TimeInterval = 0
    @State private var isViewActive = false

    private let playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let bottomInset = max(geometry.safeAreaInsets.bottom, AppSpacing.m) + AppSpacing.xl
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
        .onAppear {
            isViewActive = true
            elapsedInCurrentRange = 0
        }
        .onDisappear {
            isViewActive = false
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                elapsedInCurrentRange = 0
            }
        }
    }

    private var feedPager: some View {
        VStack(spacing: AppSpacing.s) {
            TabView(selection: $currentPageIndex) {
                ForEach(Array(viewModel.feeds.enumerated()), id: \.element.id) { index, feed in
                    let isActive = index == currentPageIndex && isViewActive

                    SocialFeedPageCardView(
                        feed: feed,
                        isVideoPlaying: isActive,
                        elapsedInCurrentRange: isActive ? elapsedInCurrentRange : 0,
                        onLikeTap: {
                            Task { await viewModel.toggleLike(diaryId: feed.diaryId) }
                        },
                        onStoreTap: {
                            Task { await viewModel.toggleStore(diaryId: feed.diaryId) }
                        },
                        onVideoPlaybackEnded: {
                            guard currentPageIndex == index else { return }
                            handleVideoPlaybackEnded(currentIndex: index, feed: feed)
                        }
                    )
                    .tag(index)
                    .padding(.top, AppSpacing.xs)
                    .padding(.horizontal, AppSpacing.xs)
                    .onAppear {
                        Task { 
                            await viewModel.loadMoreIfNeeded(currentDiaryId: feed.diaryId)
                        }
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(AppColors.primary600)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onReceive(playbackTimer) { _ in
            guard isViewActive else { return }
            elapsedInCurrentRange += 0.25
        }
        .onChange(of: currentPageIndex) { _ in
            elapsedInCurrentRange = 0
        }
    }
    
    private func handleVideoPlaybackEnded(currentIndex: Int, feed: DiaryFeedModel) {
        Task {
            let nextIndex = currentIndex + 1
            
            if nextIndex >= viewModel.feeds.count - 2 {
                await viewModel.loadMoreIfNeeded(currentDiaryId: feed.diaryId)
            }
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            guard nextIndex < viewModel.feeds.count else { return }
            
            await MainActor.run {
                elapsedInCurrentRange = 0
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentPageIndex = nextIndex
                }
            }
        }
    }
}
