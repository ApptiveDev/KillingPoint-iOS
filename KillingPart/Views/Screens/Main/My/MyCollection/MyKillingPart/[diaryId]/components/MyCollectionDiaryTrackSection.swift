import SwiftUI

struct MyCollectionDiaryTrackSection: View {
    let artworkURL: URL?
    let musicTitle: String
    let artist: String
    let startMinuteSecondText: String
    let endMinuteSecondText: String
    let startProgress: CGFloat
    let endProgress: CGFloat

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            AddSearchDetailAlbumArtworkView(url: artworkURL)
                .zIndex(2)

            VStack(alignment: .leading, spacing: 6) {
                Text(musicTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(artist)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)

                MyCollectionDiaryTimelineRangeView(
                    startMinuteSecondText: startMinuteSecondText,
                    endMinuteSecondText: endMinuteSecondText,
                    startProgress: startProgress,
                    endProgress: endProgress
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.m)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.02)
                ],
                startPoint: .trailing,
                endPoint: .leading
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
