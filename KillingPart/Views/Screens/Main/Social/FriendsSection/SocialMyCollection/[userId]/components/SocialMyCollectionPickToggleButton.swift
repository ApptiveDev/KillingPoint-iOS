import SwiftUI

struct SocialMyCollectionPickToggleButton: View {
    let isMyPick: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 6) {
                Text(isMyPick ? "나의 PICK!" : "나의 픽으로 추가")
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(isMyPick ? Color.kpPrimary : .black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.s)
            .background(isMyPick ? Color.kpGray700 : Color.kpPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
