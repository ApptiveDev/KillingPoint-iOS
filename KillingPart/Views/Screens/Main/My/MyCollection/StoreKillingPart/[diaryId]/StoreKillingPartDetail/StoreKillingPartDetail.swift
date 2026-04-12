import SwiftUI

struct StoreKillingPartDetailRoute: Hashable {
    let diaryId: Int
    let initialDiary: StoredDiaryFeedModel

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.diaryId == rhs.diaryId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(diaryId)
    }
}

struct StoreKillingPartDetail: View {
    let diaryId: Int
    let diary: StoredDiaryFeedModel
    let onStoreRemoved: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var playerReloadToken = UUID()
    @State private var isRemoveSheetPresented = false
    @State private var isRemovingStore = false
    @State private var actionErrorMessage: String?

    private let diaryService: DiaryServicing

    init(
        diaryId: Int,
        diary: StoredDiaryFeedModel,
        diaryService: DiaryServicing = DiaryService(),
        onStoreRemoved: ((Int) -> Void)? = nil
    ) {
        self.diaryId = diaryId
        self.diary = diary
        self.diaryService = diaryService
        self.onStoreRemoved = onStoreRemoved
    }

    var body: some View {
        GeometryReader { proxy in
            let topContentInset = min(proxy.safeAreaInsets.top, AppSpacing.l) + AppSpacing.s

            ZStack {
                Image("my_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.container, edges: .all)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.m) {
                        MyCollectionDiaryVideoSection(
                            videoURL: videoURL,
                            startSeconds: startSeconds,
                            endSeconds: endSeconds,
                            playerReloadToken: playerReloadToken
                        )

                        MyCollectionDiaryTrackSection(
                            artworkURL: diary.albumImageURL,
                            musicTitle: diary.musicTitle,
                            artist: diary.artist,
                            startMinuteSecondText: startMinuteSecondText,
                            endMinuteSecondText: endMinuteSecondText,
                            startProgress: startProgress,
                            endProgress: endProgress
                        )
                    }
                    .padding(.horizontal, AppSpacing.l)
                    .padding(.top, topContentInset)
                    .padding(.bottom, AppSpacing.l)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .sheet(isPresented: $isRemoveSheetPresented) {
            StoreKillingPartRemoveSheet(
                isRemoving: isRemovingStore,
                onCancel: {
                    isRemoveSheetPresented = false
                },
                onConfirm: {
                    removeFromStore()
                }
            )
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            playerReloadToken = UUID()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            if let actionErrorMessage {
                Text(actionErrorMessage)
                    .font(AppFont.paperlogy4Regular(size: 13))
                    .foregroundStyle(Color(hex: "#FF5A5A"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            actionButtonsSection
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.s)
        .padding(.bottom, AppSpacing.s)
        .background(Color.black.opacity(0.94))
    }

    private var actionButtonsSection: some View {
        VStack(spacing: AppSpacing.s) {
            NavigationLink {
                AddSearchDetailView(
                    track: registerTrack,
                    prefill: registerPrefill,
                    shouldNavigateToPlayKillingPartOnSave: false,
                    onSaveCompletedAfterDismiss: {
                        dismiss()
                    }
                )
            } label: {
                Text("내 킬링파트로 등록")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.primary600)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isRemovingStore)
            .opacity(isRemovingStore ? 0.5 : 1)

            Button {
                isRemoveSheetPresented = true
            } label: {
                Text("보관함에서 삭제")
                    .font(AppFont.paperlogy6SemiBold(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.kpGray700)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isRemovingStore)
            .opacity(isRemovingStore ? 0.5 : 1)
        }
    }

    private var registerTrack: SpotifySimpleTrack {
        SpotifySimpleTrack(
            id: "store-\(diary.diaryId)",
            title: diary.musicTitle,
            artist: diary.artist,
            albumImageUrl: diary.albumImageUrl,
            albumId: "store-\(diary.diaryId)"
        )
    }

    private var registerPrefill: AddSearchDetailPrefill {
        AddSearchDetailPrefill(
            videoURL: diary.videoUrl,
            start: diary.start,
            end: diary.end,
            totalDuration: diary.totalDuration,
            selectedScope: .killingPart
        )
    }

    private var startSeconds: Double {
        parsedSeconds(from: diary.start) ?? 0
    }

    private var endSeconds: Double {
        let parsedEnd = parsedSeconds(from: diary.end) ?? startSeconds
        return max(parsedEnd, startSeconds + 0.1)
    }

    private var totalSeconds: Double {
        let parsedTotal = parsedSeconds(from: diary.totalDuration) ?? 0
        return max(parsedTotal, endSeconds, 1)
    }

    private var startMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: startSeconds)
    }

    private var endMinuteSecondText: String {
        TimeFormatter.minuteSecondText(from: endSeconds)
    }

    private var startProgress: CGFloat {
        CGFloat(min(max(startSeconds / totalSeconds, 0), 1))
    }

    private var endProgress: CGFloat {
        CGFloat(min(max(endSeconds / totalSeconds, startSeconds / totalSeconds), 1))
    }

    private var videoURL: URL? {
        let trimmed = diary.videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalizedURLText: String
        if isLikelyYouTubeVideoID(trimmed) {
            normalizedURLText = "https://www.youtube.com/embed/\(trimmed)?playsinline=1"
        } else {
            normalizedURLText = trimmed
        }

        if let parsed = URL(string: normalizedURLText), parsed.scheme != nil {
            return parsed
        }

        if normalizedURLText.hasPrefix("//"),
           let parsed = URL(string: "https:\(normalizedURLText)") {
            return parsed
        }

        return URL(string: "https://\(normalizedURLText)")
    }

    private func isLikelyYouTubeVideoID(_ value: String) -> Bool {
        if value.hasPrefix("//") {
            return false
        }

        if let components = URLComponents(string: value),
           components.scheme != nil || components.host != nil {
            return false
        }

        return !value.contains("/")
            && !value.contains("?")
            && !value.contains("&")
            && !value.contains("=")
            && !value.contains(".")
    }

    private func parsedSeconds(from value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let raw = Double(trimmed) {
            return max(raw, 0)
        }

        let sanitized = trimmed.replacingOccurrences(of: "초", with: "")
        if sanitized.contains(":") {
            let parts = sanitized.split(separator: ":").map(String.init)
            guard
                parts.count == 2,
                let minutes = Double(parts[0]),
                let seconds = Double(parts[1])
            else {
                return nil
            }
            return max((minutes * 60) + seconds, 0)
        }

        if let raw = Double(sanitized) {
            return max(raw, 0)
        }

        return nil
    }

    private func removeFromStore() {
        guard !isRemovingStore else { return }

        Task {
            isRemovingStore = true
            actionErrorMessage = nil
            defer { isRemovingStore = false }

            do {
                _ = try await diaryService.toggleDiaryStore(diaryId: diaryId)
                NotificationCenter.default.post(name: .diaryCreated, object: nil)
                onStoreRemoved?(diaryId)
                isRemoveSheetPresented = false
                dismiss()
            } catch {
                if isRequestCancelled(error) { return }
                actionErrorMessage = resolveErrorMessage(from: error)
                isRemoveSheetPresented = false
            }
        }
    }

    private func resolveErrorMessage(from error: Error) -> String {
        if let diaryServiceError = error as? DiaryServiceError {
            return diaryServiceError.errorDescription ?? "보관함 제거에 실패했어요."
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? "보관함 제거에 실패했어요."
        }

        return "보관함 제거에 실패했어요."
    }

    private func isRequestCancelled(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

private struct StoreKillingPartRemoveSheet: View {
    let isRemoving: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.m) {
            VStack(spacing: AppSpacing.xs) {
                Text("해당 킬링파트를 더이상 보관하지 말까요?")
                    .font(AppFont.paperlogy5Medium(size: 15))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("담기를 취소하면 해당 킬링파트는\n보관함에서 사라집니다")
                    .font(AppFont.paperlogy4Regular(size: 14))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(spacing: AppSpacing.s) {
                Button(action: onCancel) {
                    Text("돌아가기")
                        .font(AppFont.paperlogy5Medium(size: 14))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRemoving)
                .opacity(isRemoving ? 0.72 : 1)

                Button(action: onConfirm) {
                    Group {
                        if isRemoving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("제거하기")
                                .font(AppFont.paperlogy5Medium(size: 14))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color(hex: "#FF5A5A"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRemoving)
                .opacity(isRemoving ? 0.72 : 1)
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.top, AppSpacing.l)
        .padding(.bottom, AppSpacing.m)
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isRemoving)
        .preferredColorScheme(.dark)
    }
}
