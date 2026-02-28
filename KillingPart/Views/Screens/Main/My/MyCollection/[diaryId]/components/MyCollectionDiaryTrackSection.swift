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

                timelineRangeSection
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

    private var timelineRangeSection: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let startX = width * startProgress
            let endX = width * endProgress
            let segmentWidth = max(endX - startX, 2)

            let labelY: CGFloat = 24
            let labelWidth: CGFloat = 38
            let halfLabelWidth = labelWidth / 2
            let minimumLabelGap = labelWidth + 4

            let clampedStartLabelX = min(max(startX, halfLabelWidth), width - halfLabelWidth)
            let clampedEndLabelX = min(max(endX, halfLabelWidth), width - halfLabelWidth)

            let initialLeftLabelX = min(clampedStartLabelX, clampedEndLabelX)
            let initialRightLabelX = max(clampedStartLabelX, clampedEndLabelX)
            let initialLabelGap = initialRightLabelX - initialLeftLabelX

            let adjustedLabelCenterX = min(
                max((initialLeftLabelX + initialRightLabelX) / 2, minimumLabelGap / 2),
                width - (minimumLabelGap / 2)
            )
            let leftLabelX = initialLabelGap < minimumLabelGap
                ? adjustedLabelCenterX - (minimumLabelGap / 2)
                : initialLeftLabelX
            let rightLabelX = initialLabelGap < minimumLabelGap
                ? adjustedLabelCenterX + (minimumLabelGap / 2)
                : initialRightLabelX

            let isStartLeft = clampedStartLabelX <= clampedEndLabelX
            let startLabelX = isStartLeft ? leftLabelX : rightLabelX
            let endLabelX = isStartLeft ? rightLabelX : leftLabelX

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: width, height: 3)
                    .offset(y: 5)

                Capsule()
                    .fill(AppColors.primary600.opacity(0.95))
                    .frame(width: segmentWidth, height: 7)
                    .offset(x: startX, y: 3)

                Text(startMinuteSecondText)
                    .font(AppFont.paperlogy6SemiBold(size: 10))
                    .foregroundStyle(AppColors.primary600.opacity(0.98))
                    .frame(width: labelWidth, alignment: .center)
                    .position(x: startLabelX, y: labelY)

                Text(endMinuteSecondText)
                    .font(AppFont.paperlogy5Medium(size: 10))
                    .foregroundStyle(AppColors.primary600.opacity(0.9))
                    .frame(width: labelWidth, alignment: .center)
                    .position(x: endLabelX, y: labelY)
            }
        }
        .frame(height: 40)
    }
}
