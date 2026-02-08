import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct OnboardingImageCardView: View {
    let imageName: String
    private let maxCardWidth: CGFloat = 280
    private let cornerRadius: CGFloat = 28
    private let aspectRatioHeightPerWidth: CGFloat = 19.5 / 9

    var body: some View {
        GeometryReader { geometry in
            let horizontalInset = AppSpacing.m * 2
            let verticalInset = AppSpacing.m
            let availableWidth = max(geometry.size.width - horizontalInset, 0)
            let availableHeight = max(
                geometry.size.height - verticalInset - geometry.safeAreaInsets.bottom,
                0
            )

            let widthByHeightLimit = availableHeight / aspectRatioHeightPerWidth
            let cardWidth = min(maxCardWidth, availableWidth, widthByHeightLimit)
            let cardHeight = cardWidth * aspectRatioHeightPerWidth

            Group {
                #if canImport(UIKit)
                if let uiImage = UIImage(named: imageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.clear
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(named: imageName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.clear
                }
                #endif
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.kpPrimary, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}
