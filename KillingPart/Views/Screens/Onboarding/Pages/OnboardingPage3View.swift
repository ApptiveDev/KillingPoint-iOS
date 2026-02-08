import SwiftUI

struct OnboardingPage3View: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Tip. 저장한 파트는 언제든 꺼내 듣고, 연습 속도를 나에게 맞게 조절할 수 있어요.")
                .font(AppFont.body())
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.m)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppColors.primary300, lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 44, weight: .semibold))
                        Text("앱 화면 3")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(AppColors.primary600)
                )
                .aspectRatio(9 / 16, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }
}
