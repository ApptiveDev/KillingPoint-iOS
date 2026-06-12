import SwiftUI

struct SocialFeedPlaybackRangeBar: View {
    let startSeconds: Double
    let endSeconds: Double
    let totalSeconds: Double
    let elapsedInCurrentRange: TimeInterval

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let startX = width * startProgress
            let endX = width * endProgress
            let segmentWidth = max(endX - startX, 2)
            let playheadX = width * playheadProgress
            let labelLayout = resolvedLabelLayout(
                rangeWidth: width,
                startX: startX,
                endX: endX
            )

            ZStack(alignment: .topLeading) {
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
                .frame(width: width, height: 12, alignment: .center)

                Text(TimeFormatter.minuteSecondText(from: startSeconds))
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .frame(width: labelLayout.width, alignment: .center)
                    .position(x: labelLayout.startX, y: 24)

                Text(TimeFormatter.minuteSecondText(from: endSeconds))
                    .font(AppFont.paperlogy4Regular(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .frame(width: labelLayout.width, alignment: .center)
                    .position(x: labelLayout.endX, y: 24)
            }
        }
    }

    private var startProgress: CGFloat {
        CGFloat(min(max(startSeconds / safeTotalSeconds, 0), 1))
    }

    private var endProgress: CGFloat {
        CGFloat(min(max(endSeconds / safeTotalSeconds, startSeconds / safeTotalSeconds), 1))
    }

    private var playheadProgress: CGFloat {
        let clampedElapsed = min(max(elapsedInCurrentRange, 0), max(endSeconds - startSeconds, 0))
        let absoluteSeconds = min(startSeconds + clampedElapsed, endSeconds)
        return CGFloat(min(max(absoluteSeconds / safeTotalSeconds, 0), 1))
    }

    private var safeTotalSeconds: Double {
        max(totalSeconds, endSeconds, startSeconds + 0.1, 0.1)
    }

    private func resolvedLabelLayout(
        rangeWidth: CGFloat,
        startX: CGFloat,
        endX: CGFloat
    ) -> (width: CGFloat, startX: CGFloat, endX: CGFloat) {
        let minimumLabelSpacing: CGFloat = 6
        let idealLabelWidth: CGFloat = 42
        let labelWidth = min(idealLabelWidth, max((rangeWidth - minimumLabelSpacing) / 2, 1))
        let labelHalfWidth = labelWidth / 2
        let minLabelCenterX = labelHalfWidth
        let maxLabelCenterX = rangeWidth - labelHalfWidth
        let minimumCenterDistance = labelWidth + minimumLabelSpacing

        var resolvedStartX = min(max(startX, minLabelCenterX), maxLabelCenterX)
        var resolvedEndX = min(max(endX, minLabelCenterX), maxLabelCenterX)
        if resolvedEndX - resolvedStartX < minimumCenterDistance {
            let midpoint = (resolvedStartX + resolvedEndX) / 2
            resolvedStartX = midpoint - (minimumCenterDistance / 2)
            resolvedEndX = midpoint + (minimumCenterDistance / 2)

            if resolvedStartX < minLabelCenterX {
                let shift = minLabelCenterX - resolvedStartX
                resolvedStartX += shift
                resolvedEndX += shift
            }

            if resolvedEndX > maxLabelCenterX {
                let shift = resolvedEndX - maxLabelCenterX
                resolvedStartX -= shift
                resolvedEndX -= shift
            }
        }

        return (labelWidth, resolvedStartX, resolvedEndX)
    }
}
