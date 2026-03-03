import SwiftUI

struct PlayKillingPartPlaylistRow: View {
    let track: PlayKillingPartTrack
    let isCurrentTrack: Bool
    let isPlaying: Bool
    let isEditMode: Bool
    let isBeingDragged: Bool
    let makeDragItemProvider: (Int) -> NSItemProvider

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            if isEditMode {
                playlistHandleIcon
                    .contentShape(Rectangle())
                    .onDrag {
                        makeDragItemProvider(track.id)
                    } preview: {
                        EmptyView()
                    }
            }

            playlistThumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(track.displayTitle)
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if !isEditMode && isCurrentTrack && isPlaying {
                Image("killingpart_music_icon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 15, height: 18)
                    .foregroundStyle(AppColors.primary600)
            }
        }
        .padding(.horizontal, AppSpacing.s)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrentTrack ? AppColors.primary600.opacity(0.16) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(isBeingDragged ? 0.45 : 1)
    }

    private var playlistHandleIcon: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .frame(width: 22, height: 22)
    }

    private var playlistThumbnail: some View {
        Group {
            if let albumURL = track.feed.albumImageURL {
                AsyncImage(url: albumURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        playlistThumbnailPlaceholder
                    @unknown default:
                        playlistThumbnailPlaceholder
                    }
                }
            } else {
                playlistThumbnailPlaceholder
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var playlistThumbnailPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
            }
    }
}
