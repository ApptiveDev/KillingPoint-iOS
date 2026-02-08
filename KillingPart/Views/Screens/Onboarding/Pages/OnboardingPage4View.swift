import SwiftUI

struct OnboardingPage4View: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Tip. 오늘 연습한 기록을 확인하면서 꾸준한 루틴을 만들어보세요.")
                .font(AppFont.paperlogy4Regular(size: 16))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.m)

            Image("onboarding_4")
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
