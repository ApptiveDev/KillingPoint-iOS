import SwiftUI

struct MyCollectionMyKillingPartSectionView: View {
    let feeds: [DiaryFeedModel]
    let isLoadingMoreFeeds: Bool
    let errorMessage: String?
    let onLikeLongPress: (DiaryFeedModel) -> Void
    let onFeedAppear: (DiaryFeedModel) -> Void
    let onBottomTriggerAppear: () -> Void

    var body: some View {
        Group {
            if feeds.isEmpty {
                emptyFeedPlaceholder
            } else {
                LazyVGrid(columns: feedGridColumns, spacing: AppSpacing.s) {
                    ForEach(feeds) { feed in
                        NavigationLink(
                            value: MyCollectionDiaryRoute(
                                diaryId: feed.diaryId,
                                initialDiary: feed
                            )
                        ) {
                            MyCollectionFeedCard(
                                feed: feed,
                                formattedUpdateDate: formattedUpdateDate(from: feed.updateDate),
                                onLikeLongPress: {
                                    onLikeLongPress(feed)
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            onFeedAppear(feed)
                        }
                    }
                }

                Color.clear
                    .frame(height: 1)
                    .id("my-collection-bottom-trigger-\(feeds.count)")
                    .onAppear {
                        onBottomTriggerAppear()
                    }
            }
        }

        if isLoadingMoreFeeds {
            HStack {
                Spacer()
                ProgressView()
                    .tint(.white.opacity(0.88))
                Spacer()
            }
            .padding(.top, AppSpacing.s)
        }

        if let errorMessage {
            Text(errorMessage)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.red.opacity(0.95))
        }
    }

    private var feedGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s),
            GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: AppSpacing.s)
        ]
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

    private func formattedUpdateDate(from rawUpdateDate: String) -> String {
        let datePart = rawUpdateDate.split(separator: "T").first.map(String.init) ?? rawUpdateDate
        return datePart.replacingOccurrences(of: "-", with: ".")
    }
}
