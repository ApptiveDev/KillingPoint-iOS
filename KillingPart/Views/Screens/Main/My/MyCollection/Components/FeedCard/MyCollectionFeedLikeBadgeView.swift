import SwiftUI

struct MyCollectionFeedLikeBadgeView: View {
    let isLiked: Bool
    let likeCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundStyle(Color.kpPrimary)

            Text("\(likeCount)")
                .foregroundStyle(Color.kpGray300)
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
