import SwiftUI

struct TutorialTrimScreen: View {
    @ObservedObject var viewModel: InitialSetupFlowViewModel

    var body: some View {
        Group {
            if let track = viewModel.selectedTrack {
                NavigationStack {
                    AddSearchDetailView(
                        track: track,
                        shouldNavigateToPlayKillingPartOnSave: false,
                        skipButtonTitle: "건너뛰기",
                        onSkip: viewModel.skipAllTutorialAndFinish,
                        isTutorialTrimFocusEnabled: true,
                        onSaveCompletedAfterDismiss: {
                            Task {
                                await viewModel.moveToTutorialHomeAfterDiarySaved()
                            }
                        }
                    )
                }
            } else {
                VStack(spacing: AppSpacing.s) {
                    Text("선택한 곡 정보가 없어요.")
                        .font(AppFont.paperlogy5Medium(size: 16))
                        .foregroundStyle(.white.opacity(0.82))
                    Button("곡 다시 선택") {
                        viewModel.startTutorialTrackSelection()
                    }
                    .buttonStyle(.plain)
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(AppColors.primary600)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            }
        }
    }
}
