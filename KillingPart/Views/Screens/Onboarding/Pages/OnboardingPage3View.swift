import SwiftUI

struct OnboardingPage3View: View {
    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.l) {
            Text("프로필을 보면 킬링파트들을 다시 확인할 수 있어요.\n 물론 코멘트도 다시 읽을 수 있답니다.")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            OnboardingImageCardView(imageName: "onboarding_3")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }
}
