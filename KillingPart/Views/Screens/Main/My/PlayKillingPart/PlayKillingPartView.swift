import SwiftUI

struct PlayKillingPartView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("킬링파트 재생")
                .font(AppFont.paperlogy7Bold(size: 24))

            Text("선택한 킬링파트를 빠르게 재생해보세요.")
                .font(AppFont.paperlogy4Regular(size: 15))
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.primary200)
                .frame(height: 220)
                .overlay {
                    VStack(spacing: AppSpacing.m) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(AppColors.primary600)

                        Text("재생 플레이어 영역")
                            .font(AppFont.paperlogy6SemiBold(size: 16))
                    }
                }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
