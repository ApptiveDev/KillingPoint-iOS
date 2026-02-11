import SwiftUI

struct OnboardingPage2View: View {
    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.l) {
            Text("킬링파트에 당신만의 코멘트를 기록해보세요.")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            OnboardingImageCardView(imageName: "onboarding_2")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }
}
