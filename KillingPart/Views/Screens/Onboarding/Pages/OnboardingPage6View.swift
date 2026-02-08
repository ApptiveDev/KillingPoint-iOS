import SwiftUI

struct OnboardingPage6View: View {
    var body: some View {
        VStack {
            Spacer()

            Text("이제 첫번째 **킬링파트**를 기록할 시간이예요!")
                .font(AppFont.paperlogy7Bold(size: 30))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white)
                .padding(.horizontal, AppSpacing.l)

            Spacer()
        }
        .padding(.bottom, AppSpacing.l)
    }
}
