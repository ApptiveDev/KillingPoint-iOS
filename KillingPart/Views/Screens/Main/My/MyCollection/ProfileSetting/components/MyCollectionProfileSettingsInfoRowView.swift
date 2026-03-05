import SwiftUI

struct MyCollectionProfileSettingsInfoRowView: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: AppSpacing.s) {
            Text(title)
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 48, alignment: .leading)

            Text(value)
                .font(AppFont.paperlogy5Medium(size: 14))
                .foregroundStyle(.white)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}
