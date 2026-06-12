import SwiftUI

struct SocialMyCollectionFeedCard: View {
    let feed: DiaryFeedModel
    let formattedUpdateDate: String
    let onLikeLongPress: () -> Void

    init(
        feed: DiaryFeedModel,
        formattedUpdateDate: String,
        onLikeLongPress: @escaping () -> Void = {}
    ) {
        self.feed = feed
        self.formattedUpdateDate = formattedUpdateDate
        self.onLikeLongPress = onLikeLongPress
    }

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            HStack {
                MyCollectionFeedLikeBadgeView(isLiked: feed.isLiked, likeCount: feed.likeCount)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        LongPressGesture(minimumDuration: 0.45)
                            .onEnded { _ in
                                onLikeLongPress()
                            }
                    )
                Spacer()
                MyCollectionFeedScopeBadgeView(scope: feed.scope)
            }

            MyCollectionFeedAlbumImageView(url: feed.albumImageURL)

            Text(feed.musicTitle)
                .font(AppFont.paperlogy6SemiBold(size: 14))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(feed.artist)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)

            Text(formattedUpdateDate)
                .font(AppFont.paperlogy4Regular(size: 12))
                .foregroundStyle(Color.kpGray300)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.s)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
