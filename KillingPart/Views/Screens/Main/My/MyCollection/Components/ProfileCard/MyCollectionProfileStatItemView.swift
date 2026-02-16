import SwiftUI

struct MyCollectionProfileStatItemView: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.xs) {
            Text(value)
                .font(AppFont.paperlogy5Medium(size: 16))
                .foregroundStyle(Color.kpPrimary)
            Text(title)
                .font(AppFont.paperlogy5Medium(size: 12))
                .foregroundStyle(Color.kpPrimary)
        }
    }
}
