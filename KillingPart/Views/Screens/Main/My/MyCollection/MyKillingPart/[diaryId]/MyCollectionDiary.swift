import SwiftUI
import UIKit

struct MyCollectionDiary: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isCommentEditorFocused: Bool

    let diaryId: Int
    let displayTag: String
    let onDiaryUpdated: ((DiaryFeedModel) -> Void)?
    let onDiaryDeleted: ((Int) -> Void)?
    @StateObject private var viewModel: MyCollectionDiaryViewModel
    @State private var isDeleteDialogPresented = false
    @State private var isShareDialogPresented = false
    @State private var isExportingImage = false
    @State private var activityShareItem: MyCollectionDiaryActivityShareItem?
    @State private var actionAlert: MyCollectionDiaryActionAlert?
    @State private var keyboardHeight: CGFloat = 0
    @State private var playerReloadToken = UUID()

    private let commentFocusAnchorID = "my-collection-diary-comment-focus-anchor"

    init(
        diaryId: Int,
        displayTag: String,
        diary: DiaryFeedModel,
        onDiaryUpdated: ((DiaryFeedModel) -> Void)? = nil,
        onDiaryDeleted: ((Int) -> Void)? = nil,
        diaryService: DiaryServicing = DiaryService()
    ) {
        self.diaryId = diaryId
        self.displayTag = displayTag
        self.onDiaryUpdated = onDiaryUpdated
        self.onDiaryDeleted = onDiaryDeleted
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
                Image("my_background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .ignoresSafeArea(.container, edges: .all)

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
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            updateKeyboardHeight(from: notification)
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            playerReloadToken = UUID()
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 0) {
                    Button {
                        handleSaveImageTap()
                    } label: {
                        toolbarIconWithTitle(named: "ic_save", title: "저장")
                    }
                    .disabled(isExportActionDisabled)
                    .opacity(isExportActionDisabled ? 0.45 : 1)
                    .accessibilityLabel("이미지 저장")

                    Button {
                        dismissKeyboard()
                        isShareDialogPresented = true
                    } label: {
                        toolbarIconWithTitle(named: "ic_share", title: "공유")
                    }
                    .disabled(isExportActionDisabled)
                    .opacity(isExportActionDisabled ? 0.45 : 1)
                    .accessibilityLabel("공유")

                    Button {
                        viewModel.beginEdit()
                    } label: {
                        toolbarIconWithTitle(named: "ic_edit", title: "수정")
                    }
                    .disabled(viewModel.isEditMode || viewModel.isProcessing)
                    .opacity((viewModel.isEditMode || viewModel.isProcessing) ? 0.45 : 1)
                    .accessibilityLabel("수정")

                    Button(role: .destructive) {
                        isDeleteDialogPresented = true
                    } label: {
                        toolbarIconWithTitle(named: "ic_trash", title: "삭제")
                    }
                    .disabled(viewModel.isProcessing)
                    .opacity(viewModel.isProcessing ? 0.45 : 1)
                    .accessibilityLabel("삭제")
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            }
        }
        .confirmationDialog(
            "공유하기",
            isPresented: $isShareDialogPresented,
            titleVisibility: .visible
        ) {
            Button("공유") {
                handleNativeShareTap()
            }
            .disabled(isExportingImage)

            Button("카카오톡 공유") {
                handleKakaoShareTap()
            }
            .disabled(isExportingImage)

            Button("인스타 스토리 공유") {
                handleInstagramStoryShareTap()
            }
            .disabled(isExportingImage)

            Button("취소", role: .cancel) {}
        } message: {
            Text("공유할 방식을 선택해 주세요.")
        }
        .confirmationDialog(
            "일기 삭제",
            isPresented: $isDeleteDialogPresented,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task {
                    let isSuccess = await viewModel.deleteDiary()
                    if isSuccess {
                        onDiaryDeleted?(diaryId)
                        dismiss()
                    }
                }
            }
            .disabled(viewModel.isProcessing)

            Button("취소", role: .cancel) {}
        } message: {
            Text("일기를 삭제하시겠습니까? 삭제된 일기는 복구할 수 없습니다.")
        }
        .sheet(item: $activityShareItem) { item in
            MyCollectionDiaryActivityShareSheet(item: item)
        }
        .alert(item: $actionAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("확인"))
            )
        }
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

    private var isExportActionDisabled: Bool {
        viewModel.isProcessing || viewModel.isDeleted || isExportingImage
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
            onDiaryUpdated?(viewModel.diary)
        }
    }

    private func handleSaveImageTap() {
        dismissKeyboard()
        Task { @MainActor in
            guard !isExportingImage else { return }
            isExportingImage = true
            defer { isExportingImage = false }

            do {
                let image = try await renderShareImage()
                try await MyCollectionDiaryPhotoSaver.save(image)
                actionAlert = MyCollectionDiaryActionAlert(
                    title: "저장 완료",
                    message: "이미지를 사진 보관함에 저장했어요."
                )
            } catch {
                actionAlert = MyCollectionDiaryActionAlert(
                    title: "저장 실패",
                    message: exportErrorMessage(from: error)
                )
            }
        }
    }

    private func handleInstagramStoryShareTap() {
        dismissKeyboard()
        Task { @MainActor in
            guard !isExportingImage else { return }
            isExportingImage = true
            defer { isExportingImage = false }

            do {
                let image = try await renderShareImage()
                guard let shareURL = DeepLinkURLBuilder.diaryURL(diaryId: diaryId) else {
                    throw MyCollectionDiaryShareExportError.shareURLUnavailable
                }
                try MyCollectionDiaryInstagramStorySharer.share(image, url: shareURL)
            } catch {
                actionAlert = MyCollectionDiaryActionAlert(
                    title: "공유 실패",
                    message: exportErrorMessage(from: error)
                )
            }
        }
    }

    private func handleKakaoShareTap() {
        dismissKeyboard()
        Task { @MainActor in
            guard !isExportingImage else { return }
            isExportingImage = true
            defer { isExportingImage = false }

            do {
                let image = try await renderShareImage()
                try await MyCollectionDiaryKakaoSharer.share(
                    image: image,
                    diary: viewModel.diary,
                    displayedContent: viewModel.displayedContent,
                    diaryId: diaryId
                )
            } catch {
                actionAlert = MyCollectionDiaryActionAlert(
                    title: "공유 실패",
                    message: exportErrorMessage(from: error)
                )
            }
        }
    }

    private func handleNativeShareTap() {
        dismissKeyboard()
        Task { @MainActor in
            guard !isExportingImage else { return }
            isExportingImage = true
            defer { isExportingImage = false }

            do {
                let image = try await renderShareImage()
                guard let shareURL = DeepLinkURLBuilder.diaryURL(diaryId: diaryId) else {
                    throw MyCollectionDiaryShareExportError.shareURLUnavailable
                }
                activityShareItem = MyCollectionDiaryActivityShareItem(
                    image: image,
                    url: shareURL
                )
            } catch {
                actionAlert = MyCollectionDiaryActionAlert(
                    title: "공유 실패",
                    message: exportErrorMessage(from: error)
                )
            }
        }
    }

    @MainActor
    private func renderShareImage() async throws -> UIImage {
        try await MyCollectionDiaryShareImageRenderer.render(
            diary: viewModel.diary,
            displayedContent: viewModel.displayedContent,
            createdDateText: createdDateText,
            tagText: tagText,
            startMinuteSecondText: viewModel.startMinuteSecondText,
            endMinuteSecondText: viewModel.endMinuteSecondText,
            startProgress: startProgress,
            endProgress: endProgress
        )
    }

    private func exportErrorMessage(from error: Error) -> String {
        if let errorDescription = (error as? LocalizedError)?.errorDescription {
            return errorDescription
        }

        return "이미지를 처리하는 중 오류가 발생했어요."
    }

    private func toolbarIconWithTitle(named name: String, title: String) -> some View {
        VStack(spacing: 2) {
            Image(name)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)

            Text(title)
                .font(AppFont.paperlogy5Medium(size: 11))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .frame(width: 36, height: 43)
        .contentShape(Rectangle())
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
