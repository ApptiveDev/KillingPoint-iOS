import SwiftUI

struct MyCollectionDiaryVideoSection: View {
    let videoURL: URL?
    let startSeconds: Double
    let endSeconds: Double

    private let videoAspectRatio: CGFloat = 16 / 9
    private let videoCornerRadius: CGFloat = 16

    var body: some View {
        YoutubePlayerView(
            videoURL: videoURL,
            startSeconds: startSeconds,
            endSeconds: endSeconds
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(videoAspectRatio, contentMode: .fill)
        .allowsHitTesting(false)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: videoCornerRadius)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .padding(.horizontal, AppSpacing.xl)
    }
}
