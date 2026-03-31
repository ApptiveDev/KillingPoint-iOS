import SwiftUI

struct SocialMyCollectionPickToggleButton: View {
    var body: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.kpPrimary)

                Text("나의 픽으로 추가")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(Color.kpPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.s)
            .background(Color.kpGray700)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
