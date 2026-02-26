import SwiftUI

struct AddSearchDetailTrackInfoSection: View {
    let track: SpotifySimpleTrack

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            AddSearchDetailAlbumArtworkView(url: track.albumImageURL)
                .zIndex(2)

            VStack(alignment: .center, spacing: 6) {
                Text(track.title)
                    .font(AppFont.paperlogy6SemiBold(size: 16))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(track.artist)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(AppSpacing.m)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),  // 오른쪽이 더 밝게
                    Color.white.opacity(0.02)   // 왼쪽이 더 어둡게
                ],
                startPoint: .trailing,   // 👉 오른쪽 시작
                endPoint: .leading       // 👉 왼쪽 끝
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
