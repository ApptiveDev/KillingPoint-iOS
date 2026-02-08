import SwiftUI

struct OnboardingPage5View: View {
    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.l) {
            Text("그날의 감정이 담긴 코멘트를 읽으며\n 킬링파트를 더 깊이 있게 감상할 수 있어요")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            

            Image("onboarding_5")
                .resizable()
                .scaledToFill() // ⭐ 꽉 채우고 남는 부분은 잘림
                .frame(height: 600)
                .frame(maxWidth: .infinity)
                .aspectRatio(9/16, contentMode: .fit) // ⭐ 컨테이너 비율 9:16 고정
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.kpPrimary, lineWidth: 1)
                )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.m)
    }
}
