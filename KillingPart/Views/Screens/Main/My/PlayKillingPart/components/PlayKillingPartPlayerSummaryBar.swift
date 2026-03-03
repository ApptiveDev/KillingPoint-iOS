import SwiftUI

struct PlayKillingPartPlayerSummaryBar: View {
    let currentTrack: PlayKillingPartTrack?
    let nextTrack: PlayKillingPartTrack?
    let isPlaylistExpanded: Bool
    let isSavingOrder: Bool
    let isEditMode: Bool
    let isPlaylistEmpty: Bool
    let elapsedInCurrentRange: TimeInterval
    let onEditButtonTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.s) {
                Text(currentTrack?.displayTitle ?? "재생할 곡 없음")
                    .font(AppFont.paperlogy6SemiBold(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Image(systemName: isPlaylistExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }

            if let currentTrack {
                PlayKillingPartPlaybackRangeBar(
                    track: currentTrack,
                    elapsedInCurrentRange: elapsedInCurrentRange
                )
                .frame(height: 24)
            } else {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)
            }

            HStack(spacing: AppSpacing.s) {
                (
                    Text("다음 곡: ")
                        .foregroundColor(AppColors.primary600)
                    +
                    Text(nextTrack?.displayTitle ?? "마지막 곡")
                        .foregroundColor(.white)
                )
                .font(AppFont.paperlogy4Regular(size: 13))
                .lineLimit(1)

                Spacer(minLength: 0)

                if isPlaylistExpanded {
                    Button {
                        onEditButtonTap()
                    } label: {
                        if isSavingOrder {
                            ProgressView()
                                .tint(AppColors.primary600)
                        } else {
                            Text(isEditMode ? "완료" : "편집")
                                .font(AppFont.paperlogy5Medium(size: 13))
                                .foregroundStyle(AppColors.primary600)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isPlaylistEmpty || isSavingOrder)
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.primary600)
                }
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct PlayKillingPartPlaybackRangeBar: View {
    let track: PlayKillingPartTrack
    let elapsedInCurrentRange: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let startX = width * track.startProgress
            let endX = width * track.endProgress
            let segmentWidth = max(endX - startX, 2)
            let playheadX = width * track.playheadProgress(elapsedInCurrentRange: elapsedInCurrentRange)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.26))
                    .frame(height: 4)

                Capsule()
                    .fill(AppColors.primary600)
                    .frame(width: segmentWidth, height: 10)
                    .offset(x: startX)

                Circle()
                    .fill(Color.white)
                    .frame(width: 11, height: 11)
                    .overlay {
                        Circle()
                            .stroke(AppColors.primary600, lineWidth: 1)
                    }
                    .offset(x: min(max(playheadX - 5.5, 0), width - 11))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
