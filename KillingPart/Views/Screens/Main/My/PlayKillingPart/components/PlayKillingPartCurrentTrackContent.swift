import SwiftUI

struct PlayKillingPartCurrentTrackContent: View {
    let track: PlayKillingPartTrack
    let isPlaying: Bool
    let playerReloadToken: UUID

    private let videoAspectRatio: CGFloat = 16 / 9
    private let videoCornerRadius: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Group {
                if let videoURL = track.videoURL {
                    YoutubePlayerView(
                        videoURL: videoURL,
                        startSeconds: track.startSeconds,
                        endSeconds: track.endSeconds,
                        isPlaying: isPlaying
                    )
                    .id("\(track.id)-\(playerReloadToken)")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(videoAspectRatio, contentMode: .fit)
                    .allowsHitTesting(false)
                    .clipShape(RoundedRectangle(cornerRadius: videoCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: videoCornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
                } else {
                    RoundedRectangle(cornerRadius: videoCornerRadius)
                        .fill(Color.white.opacity(0.08))
                        .frame(maxWidth: .infinity)
                        .aspectRatio(videoAspectRatio, contentMode: .fit)
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(AppColors.primary600)
                        }
                }
            }

            VStack(alignment: .center, spacing: 6) {
                Text(track.displayTitle)
                    .font(AppFont.paperlogy6SemiBold(size: 20))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(track.displayArtist)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, AppSpacing.m)

            VStack(alignment: .center, spacing: AppSpacing.s) {
                Text("킬링파트 일기")
                    .font(AppFont.paperlogy6SemiBold(size: 13))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(track.displayContent)
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .padding(AppSpacing.m)
        }
        .padding(.bottom, AppSpacing.m)
    }
}
