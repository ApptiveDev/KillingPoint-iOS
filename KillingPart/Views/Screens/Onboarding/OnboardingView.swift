import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            Spacer()

            Text("Welcome")
                .font(AppFont.title())

            VStack(alignment: .leading, spacing: AppSpacing.m) {
                Text("핵심 기능을 빠르게 시작할 수 있도록 기본 온보딩 화면을 구성해두었습니다.")
                    .font(AppFont.body())
                Text("프로젝트 요구사항에 맞춰 단계별 안내 문구와 이미지를 추가하면 됩니다.")
                    .font(AppFont.body())
                    .foregroundStyle(.secondary)
            }

            PrimaryButton(title: "다음") {
                onContinue()
            }

            Spacer()
        }
        .padding(AppSpacing.l)
        .background(AppColors.primary100.ignoresSafeArea())
    }
}
