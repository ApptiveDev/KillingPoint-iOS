import SwiftUI

struct MyCollectionProfileStatItemView: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            Text(value)
                .font(AppFont.paperlogy5Medium(size: 16))
                .foregroundStyle(Color.kpPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
            Text(title)
                .font(AppFont.paperlogy5Medium(size: 12))
                .foregroundStyle(Color.kpPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
        }
    }
}
