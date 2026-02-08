import SwiftUI

struct OnboardingPage5View: View {
    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.l) {
            Text("그날의 감정이 담긴 코멘트를 읽으며\n 킬링파트를 더 깊이 있게 감상할 수 있어요")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            OnboardingImageCardView(imageName: "onboarding_5")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }
}
