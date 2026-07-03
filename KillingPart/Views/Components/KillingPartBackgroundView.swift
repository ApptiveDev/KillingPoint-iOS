import SwiftUI

struct KillingPartBackgroundView: View {
    private static let artworkAspectRatio: CGFloat = 9 / 16

    var body: some View {
        GeometryReader { geometry in
            let artworkHeight = geometry.size.width / Self.artworkAspectRatio

            ZStack(alignment: .top) {
                Color(hex: "#060606")

                Image("my_background_v2")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: geometry.size.width,
                        height: artworkHeight,
                        alignment: .top
                    )
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height,
                alignment: .top
            )
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
