import SwiftUI

struct MyCollectionFeedLikeBadgeView: View {
    let isLiked: Bool
    let likeCount: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isLiked ? Color.kpPrimary : Color.white)

            Text("\(likeCount)")
                .foregroundStyle(Color.white)
        }
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.46), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.kpPrimary, lineWidth: 1.5)
        }
    }
}
