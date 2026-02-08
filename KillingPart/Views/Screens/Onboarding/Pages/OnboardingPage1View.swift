import SwiftUI

struct OnboardingPage1View: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Tip. 좋아하는 곡을 선택하면 핵심 파트를 자동으로 추천해드려요.")
                .font(AppFont.paperlogy5Medium(size: 30))

            Spacer(minLength: AppSpacing.m)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppColors.primary300, lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: AppSpacing.s) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 44, weight: .semibold))
                        Text("앱 화면 1")
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


#Preview {
    OnboardingPage1View()
}

