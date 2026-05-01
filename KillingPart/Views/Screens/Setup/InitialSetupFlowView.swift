import SwiftUI

struct InitialSetupFlowView: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel

    var body: some View {
        ZStack {
            stepContent(for: viewModel.step)
                .id(viewModel.step)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.28), value: viewModel.step)
    }

    @ViewBuilder
    private func stepContent(for step: InitialSetupFlowViewModel.Step) -> some View {
        switch step {
        case .policyAgreement:
            PolicyAgreementScreen(viewModel: viewModel)
        case .nameSetup:
            NameSetupScreen(viewModel: viewModel)
        case .tagSetup:
            TagSetupScreen(viewModel: viewModel)
        case .tutorialChoice:
            TutorialChoiceScreen(viewModel: viewModel)
        case .tutorialTrackSearch:
            TutorialTrackSearchScreen(
                onSkip: viewModel.skipAllTutorialAndFinish,
                onTrackSelected: { track in
                    viewModel.selectTutorialTrack(track)
                }
            )
        case .tutorialTrim:
            TutorialTrimScreen(viewModel: viewModel)
        case .tutorialHome:
            TutorialHomeScreen(viewModel: viewModel)
        case .tutorialDiaryDetail:
            TutorialDiaryDetailScreen(viewModel: viewModel)
        case .tutorialNotification:
            TutorialNotificationScreen(viewModel: viewModel)
        case .tutorialFinal:
            TutorialFinalScreen(viewModel: viewModel)
        }
    }
}
