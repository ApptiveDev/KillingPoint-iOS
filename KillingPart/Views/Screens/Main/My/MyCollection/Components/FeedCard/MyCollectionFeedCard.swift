import SwiftUI

struct MyCollectionFeedCard: View {
    let feed: DiaryFeedModel
    let formattedUpdateDate: String

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            HStack {
                MyCollectionFeedLikeBadgeView(isLiked: feed.isLiked, likeCount: feed.likeCount)
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
