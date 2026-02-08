import SwiftUI

struct OnboardingPage2View: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Tip. 어려운 구간은 반복 재생으로 리듬과 발음을 더 정확히 익혀보세요.")
                .font(AppFont.paperlogy4Regular(size: 16))
                .foregroundStyle(.secondary)

            Spacer(minLength: AppSpacing.m)

            Image("onboarding_2")
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
