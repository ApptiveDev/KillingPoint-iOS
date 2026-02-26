import SwiftUI

struct AddSearchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddSearchDetailViewModel
    @State private var isForwardStepTransition = true
    private let onSaved: (() -> Void)?

    init(
        track: SpotifySimpleTrack,
        onSaved: (() -> Void)? = nil
    ) {
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: AddSearchDetailViewModel(track: track))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    AddSearchDetailVideoSection(viewModel: viewModel)
                    AddSearchDetailTrackInfoSection(track: viewModel.track)
                    detailInputSection
                        .clipped()

//                    if viewModel.videos.count > 1 {
//                        AddSearchDetailVideoCandidateSection(viewModel: viewModel)
//                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .navigationTitle("음악 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var detailInputSection: some View {
        ZStack {
            if viewModel.currentStep == .trim {
                AddSearchDetailTrimSection(viewModel: viewModel)
                    .transition(stepTransition)
            } else {
                AddSearchDetailCommentSection(viewModel: viewModel)
                    .transition(stepTransition)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: viewModel.currentStep)
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if let saveErrorMessage = viewModel.saveErrorMessage {
                Text(saveErrorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.currentStep == .trim {
                PrimaryButton(title: "다음으로") {
                    moveToCommentStep()
                }
                .disabled(!viewModel.canMoveToCommentStep)
                .opacity(viewModel.canMoveToCommentStep ? 1 : 0.42)
            } else {
                HStack(spacing: AppSpacing.s) {
                    Button {
                        moveToTrimStep()
                    } label: {
                        Text("이전으로")
                            .font(AppFont.paperlogy6SemiBold(size: 16))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.m)
                            .background(Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSavingDiary)
                    .opacity(viewModel.isSavingDiary ? 0.45 : 1)

                    PrimaryButton(
                        title: "저장하기",
                        isLoading: viewModel.isSavingDiary
                    ) {
                        saveDiary()
                    }
                    .disabled(!viewModel.canSaveDiary)
                    .opacity(viewModel.canSaveDiary ? 1 : 0.42)
                }
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.s)
        .background(Color.black.opacity(0.94))
    }

    private var stepTransition: AnyTransition {
        if isForwardStepTransition {
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        }

        return .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        )
    }

    private func moveToCommentStep() {
        guard viewModel.canMoveToCommentStep else {
            _ = viewModel.moveToCommentStep()
            return
        }
        isForwardStepTransition = true
        withAnimation(.easeInOut(duration: 0.28)) {
            _ = viewModel.moveToCommentStep()
        }
    }

    private func moveToTrimStep() {
        isForwardStepTransition = false
        withAnimation(.easeInOut(duration: 0.28)) {
            viewModel.moveToTrimStep()
        }
    }

    private func saveDiary() {
        Task {
            let isSuccess = await viewModel.submitDiary()
            if isSuccess {
                onSaved?()
                dismiss()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddSearchDetailView(track: SpotifySimpleTrack(
            id: "preview-track-id",
            title: "Ditto",
            artist: "NewJeans",
            albumImageUrl: nil,
            albumId: "preview-album-id"
        ))
    }
}
