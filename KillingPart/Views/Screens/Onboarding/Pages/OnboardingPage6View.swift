import SwiftUI

struct OnboardingPage6View: View {
    var body: some View {
        VStack {
            Spacer()

            Text("이제 첫번째 **킬링파트**를 기록할 시간이예요!")
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.l)

            Spacer()
        }
        .padding(.bottom, AppSpacing.l)
    }
}
