import SwiftUI

struct AddSearchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: AddSearchDetailViewModel
    @State private var isForwardStepTransition = true
    @State private var playerReloadToken = UUID()
    @State private var isTutorialTrimFocusActive = false
    private let onSaved: (() -> Void)?
    private let shouldNavigateToPlayKillingPartOnSave: Bool
    private let onSaveCompletedAfterDismiss: (() -> Void)?
    private let skipButtonTitle: String?
    private let onSkip: (() -> Void)?
    private let isTutorialTrimFocusEnabled: Bool

    init(
        track: SpotifySimpleTrack,
        prefill: AddSearchDetailPrefill? = nil,
        shouldNavigateToPlayKillingPartOnSave: Bool = true,
        skipButtonTitle: String? = nil,
        onSkip: (() -> Void)? = nil,
        isTutorialTrimFocusEnabled: Bool = false,
        onSaveCompletedAfterDismiss: (() -> Void)? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        self.onSaved = onSaved
        self.shouldNavigateToPlayKillingPartOnSave = shouldNavigateToPlayKillingPartOnSave
        self.skipButtonTitle = skipButtonTitle
        self.onSkip = onSkip
        self.isTutorialTrimFocusEnabled = isTutorialTrimFocusEnabled
        self.onSaveCompletedAfterDismiss = onSaveCompletedAfterDismiss
        _viewModel = StateObject(
            wrappedValue: AddSearchDetailViewModel(
                track: track,
                prefill: prefill
            )
        )
    }

    var body: some View {
        let isTrimFocusActive = isTutorialTrimFocusEnabled
            && isTutorialTrimFocusActive
            && viewModel.currentStep == .trim

        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.m) {
                    if viewModel.currentStep == .comment && isTutorialTrimFocusEnabled {
                        commentVideoPlaceholder
                    } else {
                        AddSearchDetailVideoSection(
                            viewModel: viewModel,
                            playerReloadToken: playerReloadToken
                        )
                        .opacity(isTrimFocusActive ? 0.35 : 1)
                    }
                    AddSearchDetailTrackInfoSection(track: viewModel.track)
                        .opacity(isTrimFocusActive ? 0.35 : 1)
                    detailInputSection
                        .clipped()

                    if viewModel.videos.count > 1 {
                        AddSearchDetailVideoCandidateSection(viewModel: viewModel)
                            .opacity(isTrimFocusActive ? 0.35 : 1)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.m)
                .padding(.bottom, AppSpacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
                .opacity(isTrimFocusActive ? 0.35 : 1)
        }
        .safeAreaInset(edge: .top, spacing: AppSpacing.s) {
            if isTrimFocusActive {
                Text("킬링파트로 사용할 구간을 정해보세요!")
                    .font(AppFont.paperlogy7Bold(size: 32))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, AppSpacing.s)
                    .padding(.bottom, AppSpacing.xs)
                    .transition(.opacity)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            if isTutorialTrimFocusEnabled {
                isTutorialTrimFocusActive = true
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            playerReloadToken = UUID()
        }
        .onChange(of: viewModel.currentStep) { step in
            if step != .trim {
                isTutorialTrimFocusActive = false
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isTrimFocusActive {
                isTutorialTrimFocusActive = false
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("killingpartLogoGray")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                    .accessibilityLabel("KillingPart")
            }

            if let skipButtonTitle, let onSkip {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(skipButtonTitle) {
                        onSkip()
                    }
                    .font(AppFont.paperlogy5Medium(size: 14))
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var detailInputSection: some View {
        ZStack {
            if viewModel.currentStep == .trim {
                AddSearchDetailTrimSection(
                    viewModel: viewModel,
                    onTrimInteracted: {
                        if isTutorialTrimFocusActive {
                            isTutorialTrimFocusActive = false
                        }
                    },
                    onTrimInteractionEnded: { control in
                        trackCutHandleAdjusted(control: control)
                    }
                )
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

    private var commentVideoPlaceholder: some View {
        Text("선택한 구간에서 느낀\n감정과 생각을 적어보세요.")
            .font(AppFont.paperlogy6SemiBold(size: 20))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)
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
            let isMoved = viewModel.moveToCommentStep()
            if isMoved {
                trackCutCompleted()
            }
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
                if isTutorialTrimFocusEnabled {
                    trackOnboardingKillingPartCutCompleted()
                } else {
                    trackKillingPartCutCompleted()
                }
                onSaved?()
                if shouldNavigateToPlayKillingPartOnSave {
                    NotificationCenter.default.post(name: .navigateToPlayKillingPart, object: nil)
                }
                dismiss()
                if let onSaveCompletedAfterDismiss {
                    Task { @MainActor in
                        onSaveCompletedAfterDismiss()
                    }
                }
            }
        }
    }

    private func trackCutHandleAdjusted(control: AddSearchDetailTrimInteractionControl) {
        var properties = trimRangeProperties
        properties["control"] = control.rawValue
        AmplitudeClient.shared.track(eventType: "cut_handle_adjusted", properties: properties)
    }

    private func trackCutCompleted() {
        var properties = trackIdentityProperties
        properties.merge(trimRangeProperties) { _, new in new }
        AmplitudeClient.shared.track(eventType: "cut_completed", properties: properties)
    }

    private func trackKillingPartCutCompleted() {
        let totalCount = AddSearchDetailCutCounter.incrementAndGet()
        var properties = trackIdentityProperties
        properties.merge(trimRangeProperties) { _, new in new }
        properties["total_killingpart_cut_count"] = totalCount
        AmplitudeClient.shared.track(eventType: "killingpart_cut_completed", properties: properties)
    }

    private func trackOnboardingKillingPartCutCompleted() {
        var properties = trackIdentityProperties
        properties.merge(trimRangeProperties) { _, new in new }
        AmplitudeClient.shared.track(
            eventType: "onboarding_killingpart_cut_completed",
            properties: properties
        )
    }

    private var trackIdentityProperties: [String: Any] {
        [
            "track_id": viewModel.track.id,
            "track_title": viewModel.track.title,
            "track_artist": viewModel.track.artist
        ]
    }

    private var trimRangeProperties: [String: Any] {
        return [
            "start_sec": roundedSeconds(viewModel.startSeconds),
            "end_sec": roundedSeconds(viewModel.endSeconds),
            "clip_duration_sec": roundedSeconds(
                max(viewModel.endSeconds - viewModel.startSeconds, 0)
            )
        ]
    }

    private func roundedSeconds(_ seconds: Double) -> Double {
        (seconds * 100).rounded() / 100
    }
}

private enum AddSearchDetailCutCounter {
    private static let key = "amplitude_total_killingpart_cut_count"

    static func incrementAndGet() -> Int {
        let defaults = UserDefaults.standard
        let nextValue = defaults.integer(forKey: key) + 1
        defaults.set(nextValue, forKey: key)
        return nextValue
    }
}

#Preview {
    NavigationStack {
        AddSearchDetailView(track: SpotifySimpleTrack(
            id: "preview-track-id",
            title: "Ditto",
            artist: "NewJeans",
            albumImageUrl: nil,
            albumId: "preview-album-id",
            musicMetadata: nil
        ))
    }
}
