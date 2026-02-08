import SwiftUI

struct OnboardingPage1View: View {
    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.l) {
            Text("좌우로 밀어서 킬링파트 근처로 이동하고\n 양 옆의 핸들로 킬링파트를 지정해보세요!")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Image("onboarding_1")
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
