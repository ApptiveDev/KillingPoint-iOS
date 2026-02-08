import SwiftUI

struct OnboardingPage4View: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Tip. 오늘 연습한 기록을 확인하면서 꾸준한 루틴을 만들어보세요.")
                .font(AppFont.paperlogy4Regular(size: 16))
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
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 44, weight: .semibold))
                        Text("앱 화면 4")
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
