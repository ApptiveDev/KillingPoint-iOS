import SwiftUI

struct OnboardingPage4View: View {
    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.l) {
            Text("내 프로필 뿐만 아니라 캘린더에도 저장해놨어요.\n 킬링파트를 모아 나만의 캘린더를 완성해보세요.")
                .font(AppFont.paperlogy6SemiBold(size: 16))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            

            Image("onboarding_4")
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
