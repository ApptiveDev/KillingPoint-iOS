import SwiftUI

struct MyCollectionDiaryTimelineRangeView: View {
    let startMinuteSecondText: String
    let endMinuteSecondText: String
    let startProgress: CGFloat
    let endProgress: CGFloat

    var trackHeight: CGFloat = 3
    var segmentHeight: CGFloat = 7
    var labelWidth: CGFloat = 38
    var labelY: CGFloat = 24
    var height: CGFloat = 40
    var startFontSize: CGFloat = 10
    var endFontSize: CGFloat = 10
    var trackColor: Color = Color.white.opacity(0.22)
    var segmentColor: Color = AppColors.primary600.opacity(0.95)
    var startLabelColor: Color = AppColors.primary600.opacity(0.98)
    var endLabelColor: Color = AppColors.primary600.opacity(0.9)

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let startX = width * startProgress
            let endX = width * endProgress
            let segmentWidth = max(endX - startX, 2)
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
                    .fill(trackColor)
                    .frame(width: width, height: trackHeight)
                    .offset(y: 5)

                Capsule()
                    .fill(segmentColor)
                    .frame(width: segmentWidth, height: segmentHeight)
                    .offset(x: startX, y: 3)

                Text(startMinuteSecondText)
                    .font(AppFont.paperlogy6SemiBold(size: startFontSize))
                    .foregroundStyle(startLabelColor)
                    .frame(width: labelWidth, alignment: .center)
                    .position(x: startLabelX, y: labelY)

                Text(endMinuteSecondText)
                    .font(AppFont.paperlogy5Medium(size: endFontSize))
                    .foregroundStyle(endLabelColor)
                    .frame(width: labelWidth, alignment: .center)
                    .position(x: endLabelX, y: labelY)
            }
        }
        .frame(height: height)
    }
}
