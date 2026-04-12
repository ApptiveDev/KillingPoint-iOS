import SwiftUI

struct MyCollectionStoreKillingPartCard: View {
    let diary: StoredDiaryFeedModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(diary.displayOriginalAuthorTag)
                .font(AppFont.paperlogy5Medium(size: 13))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)

            MyCollectionFeedAlbumImageView(url: diary.albumImageURL)

            Text(diary.musicTitle)
                .font(AppFont.paperlogy6SemiBold(size: 14))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(diary.artist)
                .font(AppFont.paperlogy4Regular(size: 13))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.s)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
