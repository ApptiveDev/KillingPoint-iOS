import SwiftUI

struct MyCollectionProfileSettingsHeaderView: View {
    let onBackTap: () -> Void

    var body: some View {
        HStack {
            Text("프로필 설정")
                .font(AppFont.paperlogy7Bold(size: 24))
                .foregroundStyle(.white)

            Spacer()

            Button(action: onBackTap) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))

                    Text("뒤로가기")
                        .font(AppFont.paperlogy5Medium(size: 13))
                }
                .foregroundStyle(.white)
                .padding(.vertical, AppSpacing.xs)
                .padding(.horizontal, AppSpacing.s)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
