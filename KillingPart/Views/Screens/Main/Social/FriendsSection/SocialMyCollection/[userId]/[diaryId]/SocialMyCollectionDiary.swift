import SwiftUI
import UIKit

struct SocialMyCollectionDiary: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isCommentEditorFocused: Bool

    let diaryId: Int
    let displayTag: String
    let onDiaryUpdated: (() -> Void)?
    let onDiaryDeleted: ((Int) -> Void)?
    let makeCollectionViewModel: ((UserModel) -> SocialMyCollectionViewModel)?
    @StateObject private var viewModel: MyCollectionDiaryViewModel
    @State private var isDeleteDialogPresented = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var playerReloadToken = UUID()
    @State private var shouldIgnoreNextLikeTap = false
    @State private var isLikeUsersSheetPresented = false
    @State private var likeUsersSearchText = ""
    @State private var pendingNavigationUser: UserModel?
    @State private var selectedNavigationUser: UserModel?
    @State private var isUserCollectionNavigationActive = false
    @StateObject private var interactionFeedbackPresenter = SocialInteractionFeedbackPresenter()

    private let commentFocusAnchorID = "social-my-collection-diary-comment-focus-anchor"

    init(
        diaryId: Int,
        displayTag: String,
        diary: DiaryFeedModel,
        onDiaryUpdated: (() -> Void)? = nil,
        onDiaryDeleted: ((Int) -> Void)? = nil,
        makeCollectionViewModel: ((UserModel) -> SocialMyCollectionViewModel)? = nil,
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.diaryId = diaryId
        self.displayTag = displayTag
        self.onDiaryUpdated = onDiaryUpdated
        self.onDiaryDeleted = onDiaryDeleted
        self.makeCollectionViewModel = makeCollectionViewModel
        _viewModel = StateObject(
            wrappedValue: MyCollectionDiaryViewModel(
                diary: diary,
                diaryService: diaryService
            )
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let topContentInset = min(proxy.safeAreaInsets.top, AppSpacing.l) + AppSpacing.s
            let keyboardCompensation = keyboardHeight > 0 ? max(keyboardHeight - 140, 0) : 0
            let extraBottomInset = keyboardHeight > 0 ? AppSpacing.s : AppSpacing.l
            let bottomContentInset = proxy.safeAreaInsets.bottom + keyboardCompensation + extraBottomInset

            ZStack {
                KillingPartBackgroundView()

                if viewModel.isDeleted {
                    MyCollectionDiaryDeletedPlaceholder()
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: AppSpacing.m) {
                                MyCollectionDiaryVideoSection(
                                    videoURL: videoURL,
                                    startSeconds: viewModel.startSeconds,
                                    endSeconds: viewModel.endSeconds,
                                    playerReloadToken: playerReloadToken
                                )

                                MyCollectionDiaryTrackSection(
                                    artworkURL: viewModel.diary.albumImageURL,
                                    musicTitle: viewModel.diary.musicTitle,
                                    artist: viewModel.diary.artist,
                                    startMinuteSecondText: viewModel.startMinuteSecondText,
                                    endMinuteSecondText: viewModel.endMinuteSecondText,
                                    startProgress: startProgress,
                                    endProgress: endProgress
                                )

                                MyCollectionDiaryCommentSection(
                                    isEditMode: viewModel.isEditMode,
                                    displayedContent: viewModel.displayedContent,
                                    editContentDraft: $viewModel.editContentDraft,
                                    isProcessing: viewModel.isProcessing,
                                    canSubmitEdit: viewModel.canSubmitEdit,
                                    createdDateText: createdDateText,
                                    tagText: tagText,
                                    isCommentEditorFocused: $isCommentEditorFocused,
                                    onCancelTap: handleCancelTap,
                                    onSaveTap: handleSaveTap
                                )

                                if let errorMessage = viewModel.errorMessage {
                                    Text(errorMessage)
                                        .font(AppFont.paperlogy4Regular(size: 13))
                                        .foregroundStyle(.red.opacity(0.95))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id(commentFocusAnchorID)
                            }
                            .padding(.horizontal, AppSpacing.l)
                            .padding(.top, topContentInset)
                            .padding(.bottom, bottomContentInset)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismissKeyboard()
                            }
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: isCommentEditorFocused) { isFocused in
                            guard isFocused else { return }
                            DispatchQueue.main.async {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    scrollProxy.scrollTo(commentFocusAnchorID, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: keyboardHeight) { height in
                            guard isCommentEditorFocused else { return }
                            guard height > 0 else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    scrollProxy.scrollTo(commentFocusAnchorID, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .center) {
                SocialInteractionFeedbackOverlay(feedback: interactionFeedbackPresenter.activeFeedback)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onAppear {
            handleFocusActivated()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            handleFocusActivated()
        }
        .onDisappear {
            interactionFeedbackPresenter.clear()
        }
        .onChange(of: isLikeUsersSheetPresented) { isPresented in
            guard !isPresented else { return }
            viewModel.clearLikeUsersState()
            likeUsersSearchText = ""

            guard let pendingNavigationUser else { return }
            self.pendingNavigationUser = nil
            selectedNavigationUser = pendingNavigationUser
            DispatchQueue.main.async {
                isUserCollectionNavigationActive = true
            }
        }
        .onChange(of: isUserCollectionNavigationActive) { isActive in
            if !isActive {
                selectedNavigationUser = nil
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                likeButton
                storeButton
            }
        }
        .sheet(isPresented: $isLikeUsersSheetPresented) {
            SocialDiaryLikeUsersSheet(
                title: "좋아요한 사용자",
                searchText: $likeUsersSearchText,
                users: viewModel.likeUsers,
                isLoading: viewModel.isLoadingLikeUsers,
                isLoadingMore: viewModel.isLoadingMoreLikeUsers,
                errorMessage: viewModel.likeUsersErrorMessage,
                emptyMessage: "좋아요를 누른 사용자가 아직 없어요.",
                onSearchSubmit: {
                    Task {
                        await viewModel.loadLikeUsers(searchCond: normalizedLikeUsersSearchCond)
                    }
                },
                onSearchClear: {
                    likeUsersSearchText = ""
                    Task {
                        await viewModel.loadLikeUsers(searchCond: nil)
                    }
                },
                onRetry: {
                    Task {
                        await viewModel.retryLikeUsersLoading()
                    }
                },
                onUserAppear: { userId in
                    Task {
                        await viewModel.loadMoreLikeUsersIfNeeded(currentUserId: userId)
                    }
                },
                onUserTap: { user in
                    if makeCollectionViewModel != nil {
                        pendingNavigationUser = user
                    }
                    isLikeUsersSheetPresented = false
                }
            )
        }
        .background(userCollectionNavigationLink)
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    handleDoubleTapLike()
                }
        )
    }

    private var videoURL: URL? {
        let trimmed = viewModel.diary.videoUrl.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private var startProgress: CGFloat {
        CGFloat(min(max(viewModel.startSeconds / viewModel.totalSeconds, 0), 1))
    }

    private var endProgress: CGFloat {
        CGFloat(
            min(
                max(viewModel.endSeconds / viewModel.totalSeconds, viewModel.startSeconds / viewModel.totalSeconds),
                1
            )
        )
    }

    private var createdDateText: String {
        let raw = viewModel.diary.createDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "-" }
        let datePart = raw.split(separator: "T").first.map(String.init) ?? raw
        return datePart.replacingOccurrences(of: "-", with: ".")
    }

    private var tagText: String {
        let raw = displayTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "@killingpart_user" }
        return raw.hasPrefix("@") ? raw : "@\(raw)"
    }

    private func updateKeyboardHeight(from notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return
        }

        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        let overlapHeight: CGFloat
        if let keyWindow {
            let endFrameInWindow = keyWindow.convert(endFrame, from: nil)
            overlapHeight = max(
                0,
                keyWindow.bounds.maxY - endFrameInWindow.minY - keyWindow.safeAreaInsets.bottom
            )
        } else {
            overlapHeight = max(0, UIScreen.main.bounds.maxY - endFrame.minY)
        }

        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        withAnimation(.easeOut(duration: duration)) {
            keyboardHeight = overlapHeight
        }
    }

    private func handleCancelTap() {
        dismissKeyboard()
        viewModel.cancelEdit()
    }

    private func handleSaveTap() {
        dismissKeyboard()
        Task {
            let isSuccess = await viewModel.submitEdit()
            guard isSuccess else { return }
            onDiaryUpdated?()
        }
    }

    private var likeButton: some View {
        Button {
            if shouldIgnoreNextLikeTap {
                shouldIgnoreNextLikeTap = false
                return
            }
            handleLikeTap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.diary.isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(viewModel.diary.isLiked ? Color.kpPrimary : .white.opacity(0.75))
                Text(viewModel.diary.likeCount.formatted())
                    .font(AppFont.paperlogy4Regular(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLikeInteractionDisabled)
        .opacity(isLikeInteractionDisabled ? 0.6 : 1)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45)
                .onEnded { _ in
                    guard !isLikeInteractionDisabled else { return }
                    shouldIgnoreNextLikeTap = true
                    isLikeUsersSheetPresented = true
                    likeUsersSearchText = ""
                    Task {
                        await viewModel.loadLikeUsers(searchCond: nil)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        shouldIgnoreNextLikeTap = false
                    }
                }
        )
    }

    private var storeButton: some View {
        Button {
            handleStoreTap()
        } label: {
            Image(systemName: viewModel.diary.isStored ? "bookmark.fill" : "bookmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.primary600)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isLikeInteractionDisabled)
        .opacity(isLikeInteractionDisabled ? 0.6 : 1)
    }

    private func handleLikeTap() {
        guard !isLikeInteractionDisabled else { return }
        let feedback: SocialInteractionFeedbackKind = viewModel.diary.isLiked ? .likeRemoved : .likeAdded
        interactionFeedbackPresenter.show(feedback)
        Task {
            let isSuccess = await viewModel.toggleLike()
            guard isSuccess else { return }
            onDiaryUpdated?()
        }
    }

    private func handleStoreTap() {
        guard !isLikeInteractionDisabled else { return }
        let feedback: SocialInteractionFeedbackKind = viewModel.diary.isStored ? .storeRemoved : .storeAdded
        interactionFeedbackPresenter.show(feedback)
        Task {
            let isSuccess = await viewModel.toggleStore()
            guard isSuccess else { return }
            onDiaryUpdated?()
        }
    }

    private func handleDoubleTapLike() {
        guard !isLikeInteractionDisabled else { return }
        guard !viewModel.diary.isLiked else {
            interactionFeedbackPresenter.show(.alreadyLiked)
            return
        }

        interactionFeedbackPresenter.show(.likeAdded)
        Task {
            let isSuccess = await viewModel.toggleLike()
            guard isSuccess else { return }
            onDiaryUpdated?()
        }
    }

    private func handleFocusActivated() {
        playerReloadToken = UUID()
        Task {
            await viewModel.refreshInteractionStateIfNeeded(
                preferredUserId: viewModel.diary.userId > 0 ? viewModel.diary.userId : nil
            )
        }
    }

    private var userCollectionNavigationLink: some View {
        NavigationLink(
            isActive: $isUserCollectionNavigationActive,
            destination: {
                if let selectedNavigationUser,
                   let makeCollectionViewModel {
                    SocialMyCollectionView(
                        viewModel: makeCollectionViewModel(selectedNavigationUser)
                    )
                    .id(selectedNavigationUser.userId)
                } else {
                    EmptyView()
                }
            },
            label: {
                EmptyView()
            }
        )
        .hidden()
    }

    private var normalizedLikeUsersSearchCond: String? {
        let trimmed = likeUsersSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var isLikeInteractionDisabled: Bool {
        viewModel.isUpdatingInteraction || viewModel.isProcessing || viewModel.isDeleted
    }

    private func dismissKeyboard() {
        isCommentEditorFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
