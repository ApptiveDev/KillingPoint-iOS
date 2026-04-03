import SwiftUI

struct SocialMyCollectionView: View {
    @StateObject private var viewModel: SocialMyCollectionViewModel

    init(viewModel: SocialMyCollectionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.m) {
                profileCard

                if viewModel.isLoadingInitial && viewModel.feeds.isEmpty {
                    ProgressView()
                        .tint(.white.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppSpacing.xl)
                } else if viewModel.feeds.isEmpty {
                    emptyFeedPlaceholder
                } else {
                    LazyVGrid(columns: feedGridColumns, spacing: AppSpacing.s) {
                        ForEach(viewModel.feeds) { feed in
                            NavigationLink {
                                let diary = viewModel.feeds.first(where: { $0.diaryId == feed.diaryId }) ?? feed
                                SocialMyCollectionDiary(
                                    diaryId: feed.diaryId,
                                    displayTag: viewModel.displayTag,
                                    diary: diary
                                )
                            } label: {
                                SocialMyCollectionFeedCard(
                                    feed: feed,
                                    formattedUpdateDate: viewModel.formattedUpdateDate(from: feed.updateDate)
                                )
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                guard feed.id == viewModel.feeds.last?.id else { return }
                                Task {
                                    await viewModel.loadMoreFeedsIfNeeded(currentFeedId: feed.id)
                                }
                            }
                        }
                    }
                }

                if viewModel.isLoadingMoreFeeds {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white.opacity(0.88))
                        Spacer()
                    }
                    .padding(.top, AppSpacing.s)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(AppFont.paperlogy4Regular(size: 13))
                        .foregroundStyle(.red.opacity(0.95))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppSpacing.l)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadInitialDataIfNeeded()
        }
    }

    private var feedGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s)
        ]
    }

    private var profileCard: some View {
        SocialMyCollectionProfileCard(
            displayName: viewModel.displayName,
            displayTag: viewModel.displayTag,
            profileImageURL: viewModel.profileImageURL,
            killingPartStatText: viewModel.killingPartStatText,
            fanStatText: viewModel.fanStatText,
            pickStatText: viewModel.pickStatText,
            isMyPick: viewModel.isMyPick,
            onPickToggleTap: {
                Task {
                    await viewModel.toggleMyPick()
                }
            }
        )
    }

    private var emptyFeedPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.08))
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .overlay {
                Text("아직 작성한 피드가 없어요.")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}
