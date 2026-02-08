import SwiftUI

struct OnboardingPage1View: View {
    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.l) {
            Text("좌우로 밀어서 킬링파트 근처로 이동하고\n 양 옆의 핸들로 킬링파트를 지정해보세요!")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            OnboardingImageCardView(imageName: "onboarding_1")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }
}
