import SwiftUI

struct OnboardingPage3View: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Tip. 저장한 파트는 언제든 꺼내 듣고, 연습 속도를 나에게 맞게 조절할 수 있어요.")
                .font(AppFont.paperlogy4Regular(size: 16))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.m)

            Image("onboarding_3")
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
