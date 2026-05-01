import SwiftUI

struct TutorialChoiceScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text("첫번째 킬링파트를 추가해볼까요?")
                .font(AppFont.paperlogy7Bold(size: 30))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            Spacer(minLength: 0)

            VStack(spacing: AppSpacing.s) {
                PrimaryButton(title: "추가하기") {
                    viewModel.startTutorialTrackSelection()
                }
                .padding(.horizontal, AppSpacing.l)

                Button {
                    viewModel.skipAllTutorialAndFinish()
                } label: {
                    Text("건너뛰기")
                        .font(AppFont.paperlogy6SemiBold(size: 16))
                        .foregroundStyle(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.m)
                        .background(Color.white.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppSpacing.l)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(hex: "#141722")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
