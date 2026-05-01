import SwiftUI

struct TutorialFinalScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            Text("이제 킬링파트를\n시작해보세요.")
                .font(AppFont.paperlogy7Bold(size: 32))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            PrimaryButton(title: "시작하기") {
                viewModel.finishTutorial()
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(
            LinearGradient(
                colors: [Color.black, Color(hex: "#171A24")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
