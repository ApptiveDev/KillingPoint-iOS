import SwiftUI

struct SocialMyCollectionPickToggleButton: View {
    let isMyPick: Bool

    var body: some View {
        Button(action: {}) {
            HStack(alignment: .center, spacing: 6) {
                Text(isMyPick ? "나의 PICK!" : "나의 픽으로 추가")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(isMyPick ? .black : Color.kpPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.s)
            .background(isMyPick ? Color.kpPrimary : Color.kpGray700)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
