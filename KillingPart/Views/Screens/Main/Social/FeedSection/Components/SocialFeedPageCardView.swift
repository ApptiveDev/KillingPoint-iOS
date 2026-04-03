import SwiftUI

struct SocialFeedPageCardView: View {
    let feed: DiaryFeedModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack {
                SocialFeedProfileView(feed: feed)
                Spacer()
                SocialFeedScopeBadgeView(scope: feed.scope)
            }

            SocialFeedAlbumImageView(url: feed.albumImageURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.musicTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(feed.artist)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            Text(feed.content)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: feed.isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(feed.isLiked ? .red : .white.opacity(0.7))
                Text(feed.likeCount.formatted())
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
            }
        }
        .padding(AppSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        }
    }
}
