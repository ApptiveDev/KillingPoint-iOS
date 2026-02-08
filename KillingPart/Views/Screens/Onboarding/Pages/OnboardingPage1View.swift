import SwiftUI

struct OnboardingPage1View: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Tip. 좋아하는 곡을 선택하면 핵심 파트를 자동으로 추천해드려요.")
                .font(AppFont.paperlogy4Regular(size: 16))

            Spacer(minLength: AppSpacing.m)

            Image("onboarding_1")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }
}
